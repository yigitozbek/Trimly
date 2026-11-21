import Foundation

extension Planner {
    /// Stage 2: re-asks the larger model about `review` and `critical` items only, with a longer preview.
    /// Unloads the stage-1 model first (16 GB machines). Critical items never get content and never get approved here.
    @concurrent
    public func review(planID: String) async throws -> Plan {
        let plan = try store.load(id: planID)
        switch plan.state {
        case .applied: throw PlanError.alreadyApplied
        case .inProgress: throw PlanError.notReady
        case .ready: break
        }
        let settings = plan.settingsSnapshot
        // Approved items are the user's decision; a second opinion must not silently change their destination.
        // Covered items travel with their folder and a distributed folder never moves: neither needs an opinion.
        let candidates = plan.items.indices.filter {
            let item = plan.items[$0]
            return (item.status == .review || item.status == .critical) && item.approved == false
                && item.covered == false && item.folderMode != .distribute
        }
        // Running stage 2 is an explicit request, so it works even if the plan was made with the LLM disabled.
        guard let provider, candidates.isEmpty == false else {
            return plan
        }

        await provider.unload(model: settings.stage1Model)
        let scanned = try Self.scanTree(root: plan.root, settings: settings, ignore: IgnoreRules(settings: settings, now: now())).items
        let files = Dictionary(scanned.map { (Self.itemID(for: $0.url), $0) }, uniquingKeysWith: { first, _ in first })
        let rules = RuleEngine(settings: settings)

        var processed = 0
        var updates: [String: PlanItem] = [:]
        for index in candidates {
            try Task.checkCancellation()
            processed += 1
            guard let file = files[plan.items[index].id] else {
                continue
            }
            var item = plan.items[index]
            let rule = rules.match(file)
            // The user's own tag decided the category; a second opinion must not override it.
            guard rule.tag == nil else {
                continue
            }
            let request = Self.preparedRequest(for: file, rule: rule, item: &item, settings: settings, maxCharacters: 4000, pdfPages: 2)
            do {
                let result = try await provider.classify(request, model: settings.stage2Model)
                guard settings.category(forFolderName: result.targetFolder) != nil else {
                    continue
                }
                Self.applyLLM(result, decidedBy: .llm2, rule: rule, to: &item, settings: settings)
                if item.status == .ready && item.critical == false && item.kind != .folder {
                    item.approved = true
                }
                updates[item.id] = item
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A failed second opinion leaves the item exactly as it was.
            }
            progress?(PlanProgress(processed: processed, total: candidates.count, stage: 2))
        }

        // Stage 2 runs for minutes; merge its results into the plan as it is on disk *now*, under the lock:
        // an applied plan stays applied, and items changed elsewhere meanwhile (app, CLI) keep those changes.
        let started = Dictionary(plan.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return try store.withLock {
            var current = try store.load(id: planID)
            guard current.state == .ready else {
                throw PlanError.alreadyApplied
            }
            for (id, updated) in updates {
                guard let index = current.items.firstIndex(where: { $0.id == id }), current.items[index] == started[id] else {
                    continue
                }
                current.items[index] = updated
            }
            TargetAssigner.assign(&current)
            // Keep existing trashReason; only clear auto-approval for candidates after stage 2.
            for index in current.items.indices where current.items[index].trashReason != nil {
                current.items[index].approved = false
            }
            try store.save(current)
            return current
        }
    }
}
