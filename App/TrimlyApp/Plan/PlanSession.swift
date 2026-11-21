import Foundation
import Observation
import TrimlyCore

/// Life cycle of one folder's plan in a window: load or scan, edit, (stage 2, apply, undo — Task 6).
/// Every edit is written to disk immediately, so the CLI sees the same plan.
@MainActor
@Observable
final class PlanSession {
    let root: URL
    private let environment: AppEnvironment
    private(set) var plan: Plan?
    private(set) var phase = PlanPhase.idle
    private(set) var banner: String?
    private(set) var errorMessage: String?
    var searchText = ""
    @ObservationIgnored private var started = false
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastHealth: ProviderHealth?

    init(root: URL, environment: AppEnvironment) {
        self.root = root
        self.environment = environment
    }

    private var store: PlanStore { PlanStore(directory: environment.directory) }

    // MARK: Derived state

    var pendingItems: [PlanItem] {
        matching { $0.status == .review || $0.status == .critical }
    }

    var readyGroups: [CategoryGroup] {
        guard let plan else { return [] }
        let settings = plan.settingsSnapshot
        let grouped = Dictionary(grouping: matching { $0.status == .ready }, by: { $0.categoryID ?? "other" })
        return grouped.map { id, items in
            CategoryGroup(
                id: id,
                title: settings.category(id: id)?.folder.value(settings.categoryLanguage) ?? id,
                items: items,
                approval: .of(items)
            )
        }
        .sorted { $0.title < $1.title }
    }

    var skippedGroups: [SkipGroup] {
        Dictionary(grouping: matching { $0.status == .skipped }, by: { $0.skipReason ?? "?" })
            .map { SkipGroup(id: $0.key, items: $0.value) }
            .sorted { $0.id < $1.id }
    }

    var approvedCount: Int {
        plan?.items.filter { $0.approved && $0.status != .skipped && $0.target != nil }.count ?? 0
    }

    var stage2CandidateCount: Int {
        plan?.items.filter { ($0.status == .review || $0.status == .critical) && $0.approved == false }.count ?? 0
    }

    var isReadOnly: Bool {
        plan?.state == .applied
    }

    // MARK: Scanning

    /// Loads a recent ready plan for this folder (e.g. started in the CLI) or scans. Calling it again is a no-op.
    func start() async {
        guard started == false else { return }
        started = true
        if let existing = try? store.latestReady(root: root, now: environment.now()) {
            plan = existing
            return
        }
        await scan()
    }

    /// Always produces a new plan with the current settings.
    func rescan() async {
        cancel()
        plan = nil
        banner = nil
        errorMessage = nil
        started = true
        await scan()
    }

    func cancel() {
        scanTask?.cancel()
    }

    private func scan() async {
        let settings = environment.loadSettings()
        let provider = environment.makeProvider(settings)
        var useLLM = settings.llmEnabled
        if useLLM {
            let health = await provider.health()
            lastHealth = health
            if let problem = LLMReadiness.problem(health, model: settings.stage1Model) {
                banner = "\(problem); yalnızca kurallar kullanılıyor."
                useLLM = false
            }
        }
        phase = .scanning(nil)
        let task = Task { await self.runScan(settings: settings, provider: provider, useLLM: useLLM) }
        scanTask = task
        // A cancelled caller (e.g. the window's `.task` when it closes) cancels the scan too.
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        scanTask = nil
    }

    private func runScan(settings: Settings, provider: any LLMProvider, useLLM: Bool) async {
        let (progress, continuation) = AsyncStream.makeStream(of: PlanProgress.self)
        let planner = Planner(settings: settings, store: store, provider: provider, now: environment.now) { update in
            continuation.yield(update)
        }
        async let progressUpdates: Void = follow(progress) { .scanning($0) }
        do {
            plan = try await planner.makePlan(root: root, useLLM: useLLM)
            phase = .idle
        } catch is CancellationError {
            // The planner checkpointed its progress; a later start() resumes it.
            phase = .idle
            started = false
        } catch {
            phase = .failed(UserMessage.text(for: error))
        }
        continuation.finish()
        await progressUpdates
    }

    func follow(_ updates: AsyncStream<PlanProgress>, as phaseFor: (PlanProgress) -> PlanPhase) async {
        for await update in updates where phase != .idle {
            phase = phaseFor(update)
        }
    }

    // MARK: Editing

    func setCategory(_ categoryID: String, for itemID: String) {
        edit { try PlanEditor.set(&$0, itemID: itemID, categoryID: categoryID, description: nil, approve: nil) }
    }

    func setDescription(_ text: String, for itemID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        edit { try PlanEditor.set(&$0, itemID: itemID, categoryID: nil, description: trimmed, approve: nil) }
    }

    func setApproved(_ approved: Bool, for itemID: String) {
        edit { try PlanEditor.set(&$0, itemID: itemID, categoryID: nil, description: nil, approve: approved) }
    }

    /// Header checkbox of a ready category. Approving never includes critical items (PlanEditor guarantees it).
    func setGroupApproved(_ approved: Bool, categoryID: String) {
        edit { plan in
            if approved {
                _ = PlanEditor.bulkApprove(&plan, categoryID: categoryID, reviewReason: nil, minConfidence: nil, includeFolders: false)
            } else {
                _ = PlanEditor.bulkReject(&plan, categoryID: categoryID)
            }
        }
    }

    /// Re-reads the plan from disk first so changes made elsewhere (CLI apply) are respected, then saves.
    private func edit(_ change: (inout Plan) throws -> Void) {
        guard let current = plan else { return }
        var updated = (try? store.load(id: current.id)) ?? current
        do {
            try change(&updated)
            try store.save(updated)
            plan = updated
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
            plan = updated
        }
    }

    // MARK: Helpers

    private func matching(_ predicate: (PlanItem) -> Bool) -> [PlanItem] {
        guard let plan else { return [] }
        return plan.items
            .filter { predicate($0) && (searchText.isEmpty || $0.name.localizedStandardContains(searchText)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
