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
        let scanned = try FolderScanner().scan(root: root)
        let resumable = resume ? try store.latestResumable(root: root, now: startedAt).flatMap { $0.isReusable(with: settings) ? $0 : nil } : nil
        var plan = resumable
            ?? Plan(id: newPlanID(root: root, at: startedAt), root: root, createdAt: startedAt, state: .inProgress, settingsSnapshot: settings, items: [])
        let settings = plan.settingsSnapshot
        let previous = Dictionary(plan.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ignore = IgnoreRules(settings: settings, now: startedAt)
        let detector = CriticalDetector(settings: settings)
        let rules = RuleEngine(settings: settings)
        let llm = useLLM && settings.llmEnabled ? provider : nil

        var items: [PlanItem] = []
        var pending: [(index: Int, file: FileItem, rule: RuleMatch)] = []
        for file in scanned {
            let id = Self.itemID(for: file.url)
            if let kept = previous[id], kept.classified {
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
                sourceFingerprint: SourceFingerprint(size: file.sizeBytes, modifiedAt: file.modifiedAt ?? startedAt)
            )
            // Computed for skipped items too: a manual `set` may un-skip them later.
            item.critical = detector.isCritical(file)
            if let reason = ignore.skipReason(for: file) {
                item.status = .skipped
                item.skipReason = reason
                item.classified = true
            } else if ignore.isCategoryFolder(file) {
                // Never moved itself; its contents are planned (nested scanning).
                item.status = .skipped
                item.skipReason = Self.categoryFolderReason
                item.folderMode = .distribute
                item.classified = true
            } else {
                let rule = rules.match(file)
                if rule.strength == .decisive && file.kind != .folder {
                    Self.applyDecisive(rule, to: &item, settings: settings)
                } else if llm != nil {
                    pending.append((items.count, file, rule))
                } else {
                    Self.applyFallback(rule, to: &item, reason: .weakRuleNoLLM, message: nil, settings: settings)
                }
            }
            items.append(item)
        }
        plan.items = items
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
        TargetAssigner.assign(&plan)
        for index in plan.items.indices {
            let item = plan.items[index]
            plan.items[index].approved = item.status == .ready && item.critical == false && item.kind != .folder
        }
        plan.state = .ready
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
            allowedFolders: settings.categories.map { $0.folder.value(language) }
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
