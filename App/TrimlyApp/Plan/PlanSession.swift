import Foundation
import Observation
import TrimlyCore

/// Life cycle of one folder's plan in a window: load or scan, edit, stage 2, apply, undo.
/// Every edit is written to disk immediately (under the data-directory lock), so the CLI sees the same plan.
@MainActor
@Observable
final class PlanSession {
    let root: URL
    private let environment: AppEnvironment
    private(set) var plan: Plan?
    private(set) var phase = PlanPhase.idle
    private(set) var banner: String?
    private(set) var errorMessage: String?
    private(set) var lastRun: RunSummary?
    private(set) var lastUndo: UndoSummary?
    private(set) var lastHealth: ProviderHealth?
    /// Bumped on every edit attempt (also failed ones) so rows can re-sync their local state with the plan.
    private(set) var revision = 0
    private(set) var cancelledWithCheckpoint = false
    var searchText = ""
    @ObservationIgnored private var settings: Settings
    @ObservationIgnored private var started = false
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    /// Items that needed a decision when the plan was loaded / scanned / reviewed. They stay in "Karar bekleyen"
    /// after a manual edit (which makes them `ready`) until the next load, so rows do not jump away.
    @ObservationIgnored private var pendingIDs: Set<String> = []

    init(root: URL, environment: AppEnvironment) {
        self.root = root
        self.environment = environment
        self.settings = environment.loadSettings()
    }

    private var store: PlanStore { PlanStore(directory: environment.directory) }

    // MARK: Derived state

    /// Top-level pending rows first, then one group per mixed (distributed) folder, by path. A mixed folder's own
    /// row is its group's heading; rows inside nested mixed folders belong to the nearest one.
    var pendingGroups: [PendingGroup] {
        guard let plan else { return [] }
        let byID = Dictionary(plan.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var rows: [String: [PlanItem]] = [:]
        for item in matching(isPending) where Self.isMixedFolder(item) == false {
            var parent = item.parentID.flatMap { byID[$0] }
            while let folder = parent, Self.isMixedFolder(folder) == false {
                parent = folder.parentID.flatMap { byID[$0] }
            }
            rows[parent?.id ?? PendingGroup.topLevelID, default: []].append(item)
        }
        let visibleFolders = Set(matching { Self.isMixedFolder($0) && isPending($0) }.map(\.id))
        var groups: [PendingGroup] = []
        if let top = rows[PendingGroup.topLevelID] {
            groups.append(PendingGroup(id: PendingGroup.topLevelID, folder: nil, title: "Üst seviye", items: top))
        }
        for folder in plan.items.filter(Self.isMixedFolder).sorted(by: { $0.relativePath < $1.relativePath }) {
            let items = rows[folder.id] ?? []
            if items.isEmpty == false || visibleFolders.contains(folder.id) {
                groups.append(PendingGroup(id: folder.id, folder: folder, title: folder.relativePath, items: items))
            }
        }
        return groups
    }

    var pendingItems: [PlanItem] {
        pendingGroups.flatMap(\.items)
    }

    /// Shown when the scan hit the item limit.
    var scanNotice: String? {
        plan?.truncated == true ? "5.000 öğe sınırına ulaşıldı; daha derindeki öğeler taranmadı." : nil
    }

    /// Items a kept folder carries along (its covered descendants), and how many of them are critical.
    func coverage(of folder: PlanItem) -> FolderCoverage {
        guard let plan, folder.folderMode == .keep else { return FolderCoverage(count: 0, critical: 0, listed: folder.listed) }
        let prefix = folder.relativePath + "/"
        let inside = plan.items.filter { $0.covered && $0.relativePath.hasPrefix(prefix) }
        return FolderCoverage(count: inside.count, critical: inside.filter { $0.critical || $0.status == .critical }.count, listed: folder.listed)
    }

    var readyGroups: [CategoryGroup] {
        guard let plan else { return [] }
        let snapshot = plan.settingsSnapshot
        // Trash candidates have their own section; keep them out of "Hazır".
        let ready = matching {
            $0.status == .ready && pendingIDs.contains($0.id) == false && $0.trashReason == nil
        }
        return Dictionary(grouping: ready, by: { $0.categoryID ?? "other" })
            .map { id, items in
                CategoryGroup(
                    id: id,
                    title: snapshot.category(id: id)?.folder.value(snapshot.categoryLanguage) ?? id,
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

    /// Items skipped for "Son N dakikada değişti" — explains empty-looking plans after fresh downloads.
    var recentSkipCount: Int {
        let minutes = plan?.settingsSnapshot.recentMinutes ?? settings.recentMinutes
        let prefix = "Son \(minutes) dakikada"
        return skippedGroups.filter { $0.id.hasPrefix(prefix) }.reduce(0) { $0 + $1.items.count }
    }

    /// True when recent skips are ≥ 80% of non-covered items (banner should push Ignore settings).
    var recentSkipsDominate: Bool {
        guard let plan, recentSkipCount > 0 else { return false }
        let total = plan.items.filter { $0.covered == false }.count
        guard total > 0 else { return false }
        return Double(recentSkipCount) / Double(total) >= 0.8
    }

    /// Files marked as trash candidates that have not been sent to the Trash yet.
    var trashCandidates: [PlanItem] {
        matching { $0.trashReason != nil && $0.trashedRunID == nil }
    }

    /// Candidates plus items already in the Trash for this plan (for per-row undo).
    var trashSectionItems: [PlanItem] {
        matching { $0.trashReason != nil }
    }

    /// Visible pending rows that "Tümünü seç" may approve: critical items, and kept folders carrying one, are excluded.
    private var selectablePendingItems: [PlanItem] {
        let carryingCritical = plan?.foldersCarryingCritical() ?? []
        return pendingItems.filter {
            $0.critical == false && $0.status != .critical && $0.hasAction && carryingCritical.contains($0.id) == false
        }
    }

    var selectablePendingCount: Int {
        selectablePendingItems.count
    }

    var pendingApproval: ApprovalState {
        .of(selectablePendingItems)
    }

    var approvedCount: Int {
        approvedItems(in: plan).count
    }

    var stage2CandidateCount: Int {
        // Same candidates as `Planner.review`: covered items and mixed folders never get a second opinion.
        plan?.items.filter {
            ($0.status == .review || $0.status == .critical) && $0.approved == false && $0.covered == false && $0.folderMode != .distribute
        }.count ?? 0
    }

    var isReadOnly: Bool {
        plan?.state == .applied
    }

    var isBusy: Bool {
        switch phase {
        case .scanning, .reviewing, .applying: true
        case .idle, .applied, .failed: false
        }
    }

    /// A cancelled scan left a checkpoint that "Devam et" (start) resumes.
    var canResume: Bool {
        plan == nil && cancelledWithCheckpoint && isBusy == false
    }

    /// Stage 2 uses the plan's own snapshot model, so availability is checked against that model.
    var stage2Available: Bool {
        guard let lastHealth, isReadOnly == false, isBusy == false, stage2CandidateCount > 0 else { return false }
        return LLMReadiness.problem(lastHealth, model: plan?.settingsSnapshot.stage2Model ?? settings.stage2Model) == nil
    }

    var applySummary: ApplySummary {
        guard let plan else { return ApplySummary(count: 0, byCategory: [], criticalApproved: [], itemIDs: []) }
        let approved = approvedItems(in: plan)
        let snapshot = plan.settingsSnapshot
        let byCategory = Dictionary(grouping: approved, by: { $0.categoryID ?? "other" })
            .map { CategoryCount(title: snapshot.category(id: $0.key)?.folder.value(snapshot.categoryLanguage) ?? $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.title < $1.title }
        return ApplySummary(
            count: approved.count,
            byCategory: byCategory,
            criticalApproved: approved.filter(\.critical),
            itemIDs: Set(approved.map(\.id)),
            removesEmptyFolders: snapshot.removeEmptyFolders,
            isTagOnly: snapshot.targetMode == .tagOnly,
            addsCategoryTags: snapshot.targetMode != .tagOnly && snapshot.addCategoryTags
        )
    }

    // MARK: Scanning

    /// Loads a recent ready plan for this folder (e.g. started in the CLI) or scans (resuming a checkpoint).
    /// Calling it again is a no-op; after a cancelled scan it resumes ("Devam et").
    func start() async {
        guard started == false else { return }
        started = true
        cancelledWithCheckpoint = false
        phase = .scanning(nil)
        settings = environment.loadSettings()
        await refreshHealth()
        // Reuse only a plan the current engine made with exactly the current settings; anything else is stale.
        if let existing = await Self.latestReady(store, root: root, now: environment.now()), existing.isReusable(with: settings) {
            adopt(existing)
            phase = .idle
            return
        }
        await scan(resume: true)
    }

    /// Always produces a new plan with the current settings and a fresh Ollama check. Ignored while busy.
    func rescan() async {
        guard isBusy == false else { return }
        started = true
        plan = nil
        pendingIDs = []
        banner = nil
        errorMessage = nil
        lastRun = nil
        lastUndo = nil
        cancelledWithCheckpoint = false
        phase = .scanning(nil)
        settings = environment.loadSettings()
        await refreshHealth()
        await scan(resume: false)
    }

    /// Stops a running scan or stage 2 (İptal, window closing).
    func cancel() {
        activeTask?.cancel()
    }

    /// Asks Ollama for its state when the LLM is enabled; a disabled LLM is never contacted.
    func refreshHealth() async {
        settings = environment.loadSettings()
        lastHealth = settings.llmEnabled ? await environment.makeProvider(settings).health() : nil
    }

    private func scan(resume: Bool) async {
        let provider = environment.makeProvider(settings)
        var useLLM = settings.llmEnabled
        if useLLM, let problem = LLMReadiness.problem(lastHealth ?? ProviderHealth(reachable: false, availableModels: []), model: settings.stage1Model) {
            banner = "\(problem); yalnızca kurallar kullanılıyor."
            useLLM = false
        }
        phase = .scanning(nil)
        let settings = self.settings
        await runCancellable { await self.runScan(settings: settings, provider: provider, useLLM: useLLM, resume: resume) }
    }

    private func runScan(settings: Settings, provider: any LLMProvider, useLLM: Bool, resume: Bool) async {
        let (progress, continuation) = AsyncStream.makeStream(of: PlanProgress.self)
        let planner = Planner(settings: settings, store: store, provider: provider, now: environment.now) { update in
            continuation.yield(update)
        }
        async let progressUpdates: Void = follow(progress) { .scanning($0) }
        do {
            adopt(try await planner.makePlan(root: root, useLLM: useLLM, resume: resume))
            phase = .idle
        } catch is CancellationError {
            // The planner checkpointed its progress; "Devam et" (start) resumes it.
            phase = .idle
            started = false
            cancelledWithCheckpoint = true
        } catch {
            phase = .failed(UserMessage.text(for: error))
        }
        continuation.finish()
        await progressUpdates
    }

    func follow(_ updates: AsyncStream<PlanProgress>, as phaseFor: (PlanProgress) -> PlanPhase) async {
        for await update in updates where isBusy {
            phase = phaseFor(update)
        }
    }

    /// Runs long work in a stored task so `cancel()` (İptal) can stop it, and forwards the caller's
    /// cancellation (the window's `.task` when it closes) to it.
    private func runCancellable(_ work: @escaping @MainActor () async -> Void) async {
        let task = Task { await work() }
        activeTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeTask = nil
    }

    // MARK: Stage 2, apply, undo

    func runStage2() async {
        guard let current = plan, stage2Available else { return }
        let provider = environment.makeProvider(settings)
        let settings = self.settings
        phase = .reviewing(nil)
        await runCancellable { await self.performStage2(planID: current.id, settings: settings, provider: provider) }
    }

    private func performStage2(planID: String, settings: Settings, provider: any LLMProvider) async {
        let (progress, continuation) = AsyncStream.makeStream(of: PlanProgress.self)
        let planner = Planner(settings: settings, store: store, provider: provider, now: environment.now) { update in
            continuation.yield(update)
        }
        async let progressUpdates: Void = follow(progress) { .reviewing($0) }
        do {
            adopt(try await planner.review(planID: planID))
            errorMessage = nil
        } catch is CancellationError {
            reload()
        } catch {
            errorMessage = UserMessage.text(for: error)
            reload()
        }
        phase = .idle
        continuation.finish()
        await progressUpdates
    }

    /// Applies exactly what the confirmation sheet showed: if approvals changed elsewhere (another window, the CLI)
    /// since the sheet was built, nothing moves and the plan is reloaded for another look.
    func apply(confirming summary: ApplySummary) async {
        guard plan != nil, isReadOnly == false, isBusy == false, summary.count > 0 else { return }
        lastRun = nil
        lastUndo = nil
        reload()
        guard let current = plan, Set(approvedItems(in: current).map(\.id)) == summary.itemIDs else {
            errorMessage = "Plan başka bir yerde değiştirildi; onay özetini yeniden kontrol edin."
            return
        }
        phase = .applying
        do {
            let run = try await Executor(directory: environment.directory, now: environment.now).apply(planID: current.id)
            lastRun = run
            reload()
            phase = .applied(runID: run.runID)
        } catch {
            phase = .failed(UserMessage.text(for: error))
        }
    }

    func undoLastApply() async {
        guard let run = lastRun, lastUndo == nil else { return }
        do {
            lastUndo = try await Undoer(directory: environment.directory).undo(runID: run.runID)
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
        }
    }

    /// Sends one trash candidate to the system Trash (journaled single-item run). No bulk API.
    func trash(_ item: PlanItem) async {
        guard let current = plan, isBusy == false, isReadOnly == false else { return }
        lastRun = nil
        lastUndo = nil
        do {
            let run = try await Executor(directory: environment.directory, now: environment.now)
                .trash(planID: current.id, itemID: item.id)
            lastRun = run
            reload()
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
            reload()
        }
    }

    /// Restores a file previously sent with `trash(_:)` (or skips with a clear reason if Trash was emptied).
    func undoTrash(runID: String) async {
        do {
            lastUndo = try await Undoer(directory: environment.directory).undo(runID: runID)
            reload()
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
            reload()
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

    func setFolderMode(_ mode: FolderMode, for itemID: String) {
        edit { try PlanEditor.setFolderMode(&$0, itemID: itemID, mode: mode) }
    }

    func setApproved(_ approved: Bool, for itemID: String) {
        edit { try PlanEditor.set(&$0, itemID: itemID, categoryID: nil, description: nil, approve: approved) }
    }

    /// Header checkbox of a ready category: acts on that group's rows only. Never approves critical items.
    func setGroupApproved(_ approved: Bool, categoryID: String) {
        let ids = Set(readyGroups.first { $0.id == categoryID }?.items.map(\.id) ?? [])
        edit { _ = PlanEditor.setApproval(&$0, itemIDs: ids, approved: approved) }
    }

    /// "Tümünü seç / kaldır" of the pending section, over the rows currently visible (search applies).
    func setPendingApproved(_ approved: Bool) {
        let ids = Set(selectablePendingItems.map(\.id))
        edit { _ = PlanEditor.setApproval(&$0, itemIDs: ids, approved: approved) }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Re-reads the plan from disk under the data-directory lock, applies the change and saves,
    /// so changes made elsewhere (CLI apply/approve) are respected. Refused while a long operation runs.
    private func edit(_ change: (inout Plan) throws -> Void) {
        revision += 1
        guard isBusy == false else {
            errorMessage = "Bir işlem sürüyor; bitince tekrar deneyin."
            return
        }
        guard let current = plan else { return }
        let store = self.store
        do {
            plan = try store.withLock {
                var updated = try store.load(id: current.id)
                try change(&updated)
                try store.save(updated)
                return updated
            }
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
            reload()
        }
    }

    // MARK: Helpers

    private func adopt(_ newPlan: Plan) {
        plan = newPlan
        pendingIDs = Set(newPlan.items.filter { $0.status == .review || $0.status == .critical }.map(\.id))
    }

    private func reload() {
        if let current = plan, let fresh = try? store.load(id: current.id) {
            plan = fresh
        }
    }

    private func approvedItems(in plan: Plan?) -> [PlanItem] {
        plan?.items.filter { $0.approved && $0.status != .skipped && $0.hasAction } ?? []
    }

    private func isPending(_ item: PlanItem) -> Bool {
        pendingIDs.contains(item.id) || item.status == .review || item.status == .critical
    }

    private static func isMixedFolder(_ item: PlanItem) -> Bool {
        item.kind == .folder && item.folderMode == .distribute && item.status != .skipped && item.covered == false
    }

    private func matching(_ predicate: (PlanItem) -> Bool) -> [PlanItem] {
        guard let plan else { return [] }
        // Covered items travel with their kept folder; they never get a row of their own.
        return plan.items
            .filter { $0.covered == false && predicate($0) && (searchText.isEmpty || $0.name.localizedStandardContains(searchText)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Lists and decodes plan files off the main actor (plans accumulate over time).
    @concurrent
    private static func latestReady(_ store: PlanStore, root: URL, now: Date) async -> Plan? {
        try? store.latestReady(root: root, now: now)
    }
}
