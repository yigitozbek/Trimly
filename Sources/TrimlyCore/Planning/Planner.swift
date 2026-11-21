import CryptoKit
import Foundation

/// Builds a dry-run plan: scan → ignore → critical/rules → (stage-1 LLM for undecided items) → naming → targets.
/// Never touches user files; the plan is checkpointed after the rule pass and after every LLM batch.
public struct Planner: Sendable {
    let settings: Settings
    let store: PlanStore
    let provider: (any LLMProvider)?
    let now: @Sendable () -> Date
    let progress: (@Sendable (PlanProgress) -> Void)?

    public init(
        settings: Settings,
        store: PlanStore,
        provider: (any LLMProvider)?,
        now: @escaping @Sendable () -> Date = { Date() },
        progress: (@Sendable (PlanProgress) -> Void)? = nil
    ) {
        self.settings = settings
        self.store = store
        self.provider = provider
        self.now = now
        self.progress = progress
    }

    /// `@concurrent`: file and PDF reads must never run on a caller's main actor.
    /// `resume: false` always starts a new plan with the current settings ("Yeniden tara").
    @concurrent
    public func makePlan(root: URL, useLLM: Bool, resume: Bool = true) async throws -> Plan {
        let startedAt = now()
        let resumable = resume ? try store.latestResumable(root: root, now: startedAt).flatMap { $0.isReusable(with: settings) ? $0 : nil } : nil
        var plan = resumable
            ?? Plan(id: newPlanID(root: root, at: startedAt), root: root, createdAt: startedAt, state: .inProgress, settingsSnapshot: settings, items: [])
        let settings = plan.settingsSnapshot
        let previous = Dictionary(plan.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ignore = IgnoreRules(settings: settings, now: startedAt)
        let detector = CriticalDetector(settings: settings)
        let rules = RuleEngine(settings: settings)
        let llm = useLLM && settings.llmEnabled ? provider : nil
        let tree = try Self.scanTree(root: root, settings: settings, ignore: ignore)
        // A folder the scan did not enter but whose listing shows a partial download is skipped too, so it pins
        // the folders above it like a partial download that was scanned.
        let skipReasons = tree.items.map { file in
            ignore.skipReason(for: file)
                ?? (file.kind == .folder && tree.descended.contains(file.relativePath) == false && ignore.containsPartialDownload(file)
                    ? Self.partialInsideReason : nil)
        }
        let pinned = Self.pinnedFolders(tree.items, skipReasons: skipReasons, ignore: ignore)

        // Pass 1: skip reasons, fixed folders, already-organized names and folder modes.
        var items: [PlanItem] = []
        var idByPath: [String: String] = [:]
        var criticalByPath: [String: Bool] = [:]
        var unclassified: [(index: Int, file: FileItem, rule: RuleMatch)] = []
        for (offset, file) in tree.items.enumerated() {
            let id = Self.itemID(for: file.url)
            idByPath[file.relativePath] = id
            if let kept = previous[id], kept.classified {
                criticalByPath[file.relativePath] = kept.critical
                items.append(kept)
                continue
            }
            var item = PlanItem(
                id: id,
                name: file.name,
                source: file.url,
                kind: file.kind,
                fileExtension: file.kind == .folder ? "" : file.fileExtension,
                resolvedDate: DateResolver.resolve(file),
                status: .review,
                sourceFingerprint: SourceFingerprint(size: file.sizeBytes, modifiedAt: file.modifiedAt ?? startedAt),
                relativePath: file.relativePath,
                depth: file.depth,
                parentID: file.parentRelativePath.flatMap { idByPath[$0] },
                modeLock: Self.modeLock(for: file, pinnedBy: pinned[file.relativePath], ignore: ignore),
                listed: file.kind == .folder && tree.descended.contains(file.relativePath)
            )
            // Computed for skipped items too: a manual `set` may un-skip them later. Inherited: everything inside a
            // folder that is critical by name ("Kimlik", "Bordro"…) stays critical when the folder is distributed.
            item.critical = detector.isCritical(file) || (file.parentRelativePath.flatMap { criticalByPath[$0] } ?? false)
            criticalByPath[file.relativePath] = item.critical
            if let reason = skipReasons[offset] {
                item.status = .skipped
                item.skipReason = reason
                item.classified = true
            } else if ignore.isCategoryFolder(file) || ignore.isYearFolderInCategory(file) {
                // Never moved itself; its contents are planned (nested scanning).
                item.status = .skipped
                item.skipReason = ignore.isCategoryFolder(file) ? Self.categoryFolderReason : Self.yearFolderReason
                item.folderMode = .distribute
                item.classified = true
            } else {
                let organized = OrganizedName.match(file, settings: settings)
                if file.kind == .folder {
                    let isPinned = pinned[file.relativePath] != nil
                    item.folderMode = organized != nil && isPinned == false
                        ? .keep
                        : FolderModeDecider.mode(for: file, descended: tree.descended.contains(file.relativePath), hasPinnedDescendant: isPinned, settings: settings)
                }
                if let organized, item.folderMode != .distribute {
                    Self.applyOrganized(organized, to: &item)
                } else {
                    unclassified.append((items.count, file, rules.match(file)))
                }
            }
            items.append(item)
        }
        plan.items = items
        plan.truncated = tree.truncated
        CoverageResolver.apply(&plan)

        // Pass 2: rules for everything; the LLM only for weak matches that are planned on their own (not covered).
        var pending: [(index: Int, file: FileItem, rule: RuleMatch)] = []
        for entry in unclassified {
            var item = plan.items[entry.index]
            if entry.file.kind == .folder && item.folderMode == .distribute {
                Self.applyFallback(entry.rule, to: &item, reason: .weakRuleNoLLM, message: nil, settings: settings)
                item.status = item.critical ? .critical : .review
                item.reviewReason = .mixedFolder
            } else if entry.rule.strength == .decisive && entry.file.kind != .folder {
                Self.applyDecisive(entry.rule, to: &item, settings: settings)
            } else if llm != nil && item.covered == false {
                pending.append(entry)
            } else {
                Self.applyFallback(entry.rule, to: &item, reason: .weakRuleNoLLM, message: nil, settings: settings)
            }
            plan.items[entry.index] = item
        }
        try store.save(plan)

        if let llm {
            let batchSize = max(settings.batchSize, 1)
            var processed = 0
            for start in stride(from: 0, to: pending.count, by: batchSize) {
                for entry in pending[start..<min(start + batchSize, pending.count)] {
                    try Task.checkCancellation()
                    var item = plan.items[entry.index]
                    let request = Self.preparedRequest(for: entry.file, rule: entry.rule, item: &item, settings: settings, maxCharacters: 1500, pdfPages: 1)
                    do {
                        let result = try await llm.classify(request, model: settings.stage1Model)
                        Self.applyLLM(result, decidedBy: .llm1, rule: entry.rule, to: &item, settings: settings)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        Self.applyFallback(entry.rule, to: &item, reason: .llmError, message: "LLM yanıtı geçersiz: \(error)", settings: settings)
                    }
                    plan.items[entry.index] = item
                    processed += 1
                }
                try store.save(plan)
                progress?(PlanProgress(processed: processed, total: pending.count, stage: 1))
            }
        }

        Self.finalize(&plan)
        try store.save(plan)
        return plan
    }

    public static func stats(_ plan: Plan) -> PlanStats {
        PlanStats(plan: plan)
    }

    // MARK: - Shared with review / editing

    static let categoryFolderReason = "Trimly kategori klasörü (içi düzenlenir)"
    static let yearFolderReason = "Yıl klasörü (içi düzenlenir)"

    static func itemID(for url: URL) -> String {
        SHA256.hash(data: Data(url.standardizedFileURL.path.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    static func finalize(_ plan: inout Plan) {
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        for index in plan.items.indices {
            let item = plan.items[index]
            plan.items[index].approved = item.status == .ready && item.critical == false && item.kind != .folder && item.covered == false
        }
        plan.state = .ready
    }

    /// The tree the planner (and stage 2) works on: never descends into skipped folders (projects, recent, links…).
    static func scanTree(root: URL, settings: Settings, ignore: IgnoreRules) throws -> ScanTree {
        try FolderScanner().scanTree(root: root, maxDepth: max(settings.scanDepth, 1)) { ignore.skipReason(for: $0) == nil }
    }

    static let partialInsideReason = "İçinde yarım indirme"

    /// Folders that must not move as one unit, with the skip reason of the (first) descendant that pins them.
    private static func pinnedFolders(_ files: [FileItem], skipReasons: [String?], ignore: IgnoreRules) -> [String: String] {
        var pinned: [String: String] = [:]
        for (file, reason) in zip(files, skipReasons) {
            guard let reason, ignore.movesWithParent(file) == false else { continue }
            var ancestor = file.parentRelativePath
            while let path = ancestor, pinned[path] == nil {
                pinned[path] = reason
                ancestor = path.lastIndex(of: "/").map { String(path[..<$0]) }
            }
        }
        return pinned
    }

    /// Why a folder must stay distributed, stored on the item so no later edit can switch it to `keep`.
    private static func modeLock(for file: FileItem, pinnedBy reason: String?, ignore: IgnoreRules) -> String? {
        guard file.kind == .folder else { return nil }
        if ignore.isCategoryFolder(file) {
            return "Trimly kategori klasörü"
        }
        if ignore.isYearFolderInCategory(file) {
            return "Yıl klasörü"
        }
        return reason.map { "İçinde taşınmaması gereken öğe var (\($0))" }
    }

    /// Already carries Trimly's name inside its category folder: same category and description, so the target is
    /// the item itself in place (`Zaten düzenli`) or the same name in the central archive.
    private static func applyOrganized(_ match: OrganizedName.Match, to item: inout PlanItem) {
        item.categoryID = match.categoryID
        item.description = match.description
        item.confidence = 1.0
        item.decidedBy = .rule
        item.classified = true
        item.reason = "Zaten Trimly adıyla kategori klasöründe"
        if item.kind == .folder {
            item.status = item.critical ? .critical : .review
            item.reviewReason = item.critical ? nil : .folder
        } else {
            item.status = item.critical ? .critical : .ready
            item.reviewReason = nil
        }
    }

    /// Categories whose contents are sensitive: an LLM verdict here makes the item critical (no auto-approval).
    static let sensitiveCategoryIDs: Set<String> = ["certificates", "health", "officialDocs"]

    /// Builds the LLM request. Critical items get no preview; a preview that contains key material is dropped
    /// and marks the item critical before anything is sent.
    static func preparedRequest(for file: FileItem, rule: RuleMatch, item: inout PlanItem, settings: Settings, maxCharacters: Int, pdfPages: Int) -> ClassificationRequest {
        let language = settings.categoryLanguage
        var preview = item.critical == false && settings.contentPreview && file.kind == .file
            ? ContentPreview.text(for: file.url, maxCharacters: maxCharacters, pdfPages: pdfPages)
            : nil
        if let text = preview, SecretScanner.containsSecret(text) {
            item.critical = true
            preview = nil
        }
        return ClassificationRequest(
            name: file.name,
            fileExtension: file.fileExtension,
            kind: file.kind,
            sizeBytes: file.sizeBytes,
            createdAt: file.createdAt,
            modifiedAt: file.modifiedAt,
            utType: file.utTypeIdentifier,
            sourceHost: ClassificationRequest.sourceHost(from: file.spotlightWhereFroms),
            spotlightTitle: file.spotlightTitle,
            spotlightAuthors: file.spotlightAuthors,
            ruleHintCategoryFolder: settings.category(id: rule.categoryID)?.folder.value(language),
            folderSampleNames: file.folderSampleNames,
            contentPreview: preview,
            allowedFolders: settings.categories.map { $0.folder.value(language) },
            relativePath: file.depth > 0 ? file.relativePath : nil
        )
    }

    static func applyLLM(_ result: ClassificationResult, decidedBy: DecidedBy, rule: RuleMatch, to item: inout PlanItem, settings: Settings) {
        guard let category = settings.category(forFolderName: result.targetFolder) else {
            applyFallback(rule, to: &item, reason: .llmError, message: "LLM yanıtı geçersiz: bilinmeyen klasör", settings: settings)
            return
        }
        item.categoryID = category.id
        if sensitiveCategoryIDs.contains(category.id) {
            item.critical = true
        }
        item.confidence = result.confidence
        item.reason = String(result.reason.prefix(160))
        item.decidedBy = decidedBy
        item.description = describe(item, llm: result.suggestedName, hint: rule.descriptionHint, category: category, settings: settings)
        item.classified = true
        if item.critical {
            item.status = .critical
            item.reviewReason = nil
        } else if item.kind == .folder {
            item.status = .review
            item.reviewReason = .folder
        } else if result.confidence < settings.confidenceThreshold {
            item.status = .review
            item.reviewReason = .lowConfidence
        } else {
            item.status = .ready
            item.reviewReason = nil
        }
    }

    static func describe(_ item: PlanItem, llm: String?, hint: String?, category: Category, settings: Settings) -> String {
        let terms = settings.categoryTerms(category)
        let stem = item.fileExtension.isEmpty ? item.name : String(item.name.dropLast(item.fileExtension.count + 1))
        for candidate in [llm, hint, stem].compactMap({ $0 }) {
            if let clean = DescriptionSanitizer.sanitize(candidate, originalExtension: item.fileExtension, categoryTerms: terms) {
                return clean
            }
        }
        let slug = Normalizer.slug(stem)
        return slug.isEmpty ? (settings.categoryLanguage == .tr ? "Dosya" : "File") : slug
    }

    // MARK: - Private

    private static func applyDecisive(_ rule: RuleMatch, to item: inout PlanItem, settings: Settings) {
        item.categoryID = rule.categoryID
        item.confidence = 1.0
        item.decidedBy = .rule
        item.classified = true
        item.status = item.critical ? .critical : .ready
        item.reviewReason = nil
        if let category = settings.category(id: rule.categoryID) {
            item.description = describe(item, llm: nil, hint: rule.descriptionHint, category: category, settings: settings)
        }
    }

    private static func applyFallback(_ rule: RuleMatch, to item: inout PlanItem, reason: ReviewReason, message: String?, settings: Settings) {
        item.categoryID = rule.categoryID
        item.confidence = 0.6
        item.decidedBy = .rule
        item.classified = true
        if let message {
            item.reason = String(message.prefix(160))
        }
        if let category = settings.category(id: rule.categoryID) {
            item.description = describe(item, llm: nil, hint: rule.descriptionHint, category: category, settings: settings)
        }
        if item.critical {
            item.status = .critical
            item.reviewReason = nil
        } else {
            item.status = .review
            item.reviewReason = item.kind == .folder && reason == .weakRuleNoLLM ? .folder : reason
        }
    }

    private func newPlanID(root: URL, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let folder = Normalizer.slug(root.lastPathComponent)
        let base = "\(formatter.string(from: date))_\(folder.isEmpty ? "Klasor" : folder)"
        var id = base
        var counter = 2
        while store.exists(id: id) {
            id = "\(base)-\(counter)"
            counter += 1
        }
        return id
    }
}
