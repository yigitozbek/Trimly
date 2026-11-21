import Foundation

extension Planner {
    /// Stage 2: re-asks the larger model about `review` and `critical` items only, with a longer preview.
    /// Unloads the stage-1 model first (16 GB machines). Critical items never get content and never get approved here.
    @concurrent
    public func review(planID: String) async throws -> Plan {
        var plan = try store.load(id: planID)
        switch plan.state {
        case .applied: throw PlanError.alreadyApplied
        case .inProgress: throw PlanError.notReady
        case .ready: break
        }
        let settings = plan.settingsSnapshot
        // Approved items are the user's decision; a second opinion must not silently change their destination.
        let candidates = plan.items.indices.filter {
            (plan.items[$0].status == .review || plan.items[$0].status == .critical) && plan.items[$0].approved == false
        }
        // Running stage 2 is an explicit request, so it works even if the plan was made with the LLM disabled.
        guard let provider, candidates.isEmpty == false else {
            return plan
        }

        await provider.unload(model: settings.stage1Model)
        let scanned = try FolderScanner().scan(root: plan.root)
        let files = Dictionary(scanned.map { (Self.itemID(for: $0.url), $0) }, uniquingKeysWith: { first, _ in first })
        let rules = RuleEngine(settings: settings)

        var processed = 0
        for index in candidates {
            try Task.checkCancellation()
            processed += 1
            guard let file = files[plan.items[index].id] else {
                continue
            }
            var item = plan.items[index]
            let rule = rules.match(file)
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
                plan.items[index] = item
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A failed second opinion leaves the item exactly as it was.
            }
            progress?(PlanProgress(processed: processed, total: candidates.count, stage: 2))
        }

        TargetAssigner.assign(&plan)
        try store.save(plan)
        return plan
    }
}
