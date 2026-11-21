import Foundation

/// Applies the approved items of a plan. Moves only (`FileManager.moveItem`, which refuses to overwrite),
/// each one journaled `pending` → move → `done`, so every run can be undone. Category tags are written after
/// a successful move (or alone in `tagOnly` mode) and journaled the same way.
public struct Executor: Sendable {
    private let directory: DataDirectory
    private let now: @Sendable () -> Date

    public init(directory: DataDirectory, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
    }

    /// `@concurrent`: file moves never run on a caller's main actor. Holds the data-directory lock throughout.
    @concurrent
    public func apply(planID: String) async throws -> RunSummary {
        let lock = try DataLock.acquire(in: directory)
        return try withExtendedLifetime(lock) {
            try applyLocked(planID: planID)
        }
    }

    /// Moves one Trash candidate to the system Trash. Own small run; plan stays `.ready`.
    @concurrent
    public func trash(planID: String, itemID: String) async throws -> RunSummary {
        let lock = try DataLock.acquire(in: directory)
        return try withExtendedLifetime(lock) {
            try trashLocked(planID: planID, itemID: itemID)
        }
    }

    private func applyLocked(planID: String) throws -> RunSummary {
        let store = PlanStore(directory: directory)
        var plan = try store.load(id: planID)
        switch plan.state {
        case .applied: throw ExecutionError.alreadyApplied
        case .inProgress: throw ExecutionError.notReady
        case .ready: break
        }

        let runID = newRunID()
        var journal = try Journal.create(
            at: directory.runsURL.appending(path: "\(runID).jsonl"),
            header: JournalEntry(seq: 0, type: "header", runID: runID, planID: plan.id, root: plan.root.path, at: now())
        )
        var moved = 0
        var tagged = 0
        var movedSources: [URL] = []
        var skipped: [SkippedEntry] = []
        var failed: [SkippedEntry] = []

        for item in plan.items where item.approved && item.status != .skipped && item.hasAction {
            let needsMove = item.target != nil
            let needsTag = item.tagsToAdd.isEmpty == false
            guard let current = SourceFingerprint.read(from: item.source) else {
                skipped.append(SkippedEntry(path: item.source.path, reason: "Kaynak bulunamadı"))
                continue
            }
            guard item.sourceFingerprint.matches(current) else {
                skipped.append(SkippedEntry(path: item.source.path, reason: "Kaynak değişmiş"))
                continue
            }

            var finalURL = item.source
            if needsMove, let plannedTarget = item.target {
                do {
                    try createFolders(for: plannedTarget.deletingLastPathComponent(), journal: &journal)
                    let target = freeTarget(plannedTarget, source: item.source, plan: plan)
                    let seq = try journal.append(JournalEntry(
                        seq: -1, op: .move, state: .pending, from: item.source.path, to: target.path,
                        size: current.size, mtime: current.modifiedAt
                    ))
                    do {
                        try FileManager.default.moveItem(at: item.source, to: target)
                        try journal.append(JournalEntry(seq: -1, ref: seq, state: .done))
                        moved += 1
                        movedSources.append(item.source)
                        finalURL = target
                    } catch {
                        try journal.append(JournalEntry(seq: -1, ref: seq, state: .failed, message: error.localizedDescription))
                        failed.append(SkippedEntry(path: item.source.path, reason: "Taşıma hatası: \(error.localizedDescription)"))
                        continue
                    }
                } catch {
                    failed.append(SkippedEntry(path: item.source.path, reason: "Taşıma hatası: \(error.localizedDescription)"))
                    continue
                }
            }

            if needsTag {
                let previous: [String]
                do {
                    previous = try FinderTags.read(finalURL)
                } catch {
                    failed.append(SkippedEntry(
                        path: finalURL.path, reason: "Etiketler okunamadı: \(error.localizedDescription)"
                    ))
                    continue
                }
                let missing = item.tagsToAdd.filter { FinderTags.contains($0, in: previous) == false }
                guard missing.isEmpty == false else { continue }
                let tags = previous + missing
                let seq = try journal.append(JournalEntry(
                    seq: -1, op: .tag, state: .pending, path: finalURL.path, tags: tags, previousTags: previous
                ))
                do {
                    try FinderTags.write(tags, to: finalURL)
                    try journal.append(JournalEntry(seq: -1, ref: seq, state: .done))
                    tagged += 1
                } catch {
                    // Write either replaced the list or threw; put the journaled previous set back either way.
                    try? FinderTags.write(previous, to: finalURL)
                    try journal.append(JournalEntry(
                        seq: -1, ref: seq, state: .failed, message: "Etiket eklenemedi: \(error.localizedDescription)"
                    ))
                    failed.append(SkippedEntry(
                        path: finalURL.path, reason: "Etiket eklenemedi: \(error.localizedDescription)"
                    ))
                }
            }
        }

        if plan.settingsSnapshot.removeEmptyFolders {
            try removeEmptiedFolders(after: movedSources, root: plan.root, journal: &journal)
        }

        plan.state = .applied
        plan.appliedRunID = runID
        try store.save(plan)
        return RunSummary(runID: runID, moved: moved, skipped: skipped, failed: failed, tagged: tagged)
    }

    private func trashLocked(planID: String, itemID: String) throws -> RunSummary {
        let store = PlanStore(directory: directory)
        var plan = try store.load(id: planID)
        switch plan.state {
        case .applied: throw ExecutionError.alreadyApplied
        case .inProgress: throw ExecutionError.notReady
        case .ready: break
        }
        guard let index = plan.items.firstIndex(where: { $0.id == itemID }) else {
            throw PlanError.itemNotFound(itemID)
        }
        let item = plan.items[index]
        guard item.trashReason != nil,
              item.trashedRunID == nil,
              item.critical == false,
              item.covered == false,
              item.kind != .folder else {
            throw ExecutionError.notTrashCandidate
        }
        guard let current = SourceFingerprint.read(from: item.source) else {
            return RunSummary(runID: "", moved: 0, skipped: [SkippedEntry(path: item.source.path, reason: "Kaynak bulunamadı")], failed: [])
        }
        guard item.sourceFingerprint.matches(current) else {
            return RunSummary(
                runID: "",
                moved: 0,
                skipped: [SkippedEntry(path: item.source.path, reason: "Kaynak değişmiş")],
                failed: []
            )
        }

        let runID = newRunID()
        var journal = try Journal.create(
            at: directory.runsURL.appending(path: "\(runID).jsonl"),
            header: JournalEntry(
                seq: 0, type: "header", runID: runID, planID: plan.id, root: plan.root.path, at: now(),
                message: "Çöp: \(item.name)"
            )
        )
        do {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: item.source, resultingItemURL: &resulting)
            guard let trashPath = (resulting as URL?)?.path else {
                return RunSummary(
                    runID: runID, moved: 0, skipped: [],
                    failed: [SkippedEntry(path: item.source.path, reason: "Çöp yolu alınamadı")],
                    trashed: 0
                )
            }
            // `to` is only known after trashItem; pending+done still lets Recovery finish a torn done line.
            let seq = try journal.append(JournalEntry(
                seq: -1, op: .trash, state: .pending, from: item.source.path, to: trashPath,
                size: current.size, mtime: current.modifiedAt
            ))
            try journal.append(JournalEntry(seq: -1, ref: seq, state: .done))
        } catch {
            return RunSummary(
                runID: runID,
                moved: 0,
                skipped: [],
                failed: [SkippedEntry(path: item.source.path, reason: "Çöp'e atılamadı: \(error.localizedDescription)")],
                trashed: 0
            )
        }

        plan.items[index].trashedRunID = runID
        try store.save(plan)
        return RunSummary(runID: runID, moved: 0, skipped: [], failed: [], trashed: 1)
    }

    /// Creates missing folders top-down and journals each one so undo can remove it if it ends up empty.
    private func createFolders(for folder: URL, journal: inout Journal) throws {
        var missing: [URL] = []
        var cursor = folder.standardizedFileURL
        while FileManager.default.fileExists(atPath: cursor.path) == false && cursor.path != "/" {
            missing.insert(cursor, at: 0)
            cursor = cursor.deletingLastPathComponent()
        }
        for url in missing {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            try journal.append(JournalEntry(seq: -1, op: .mkdir, state: .done, path: url.path))
        }
    }

    /// Folders this run emptied: parents of moved sources and their ancestors strictly below the root, deepest first.
    /// Only a real directory that is empty, or holds nothing but a regular `.DS_Store` (removed and not restored on
    /// undo; Finder recreates it), is removed, journaled `rmdir` pending → `rmdir(2)` → done. Never the root, never
    /// a folder nothing was moved out of.
    private func removeEmptiedFolders(after sources: [URL], root: URL, journal: inout Journal) throws {
        // No `standardizedFileURL`: it drops `/private` only for paths that still exist, and the sources are gone.
        // Sources are built from the root, so both share its form.
        let rootPath = root.path
        var folders: Set<String> = []
        for source in sources {
            var cursor = source.deletingLastPathComponent()
            while cursor.path.hasPrefix(rootPath + "/"), folders.insert(cursor.path).inserted {
                cursor = cursor.deletingLastPathComponent()
            }
        }
        let deepestFirst = folders.sorted { lhs, rhs in
            let (l, r) = (lhs.split(separator: "/").count, rhs.split(separator: "/").count)
            return l == r ? lhs < rhs : l > r
        }
        for path in deepestFirst {
            var info = stat()
            guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
                  let contents = try? FileManager.default.contentsOfDirectory(atPath: path),
                  contents.isEmpty || contents == [".DS_Store"] else {
                continue
            }
            let seq = try journal.append(JournalEntry(seq: -1, op: .rmdir, state: .pending, path: path))
            if contents == [".DS_Store"] {
                let dsStore = (path as NSString).appendingPathComponent(".DS_Store")
                var dsInfo = stat()
                if lstat(dsStore, &dsInfo) == 0, dsInfo.st_mode & S_IFMT == S_IFREG {
                    unlink(dsStore)
                }
            }
            if rmdir(path) == 0 {
                try journal.append(JournalEntry(seq: -1, ref: seq, state: .done))
            } else {
                try journal.append(JournalEntry(seq: -1, ref: seq, state: .failed, message: String(cString: strerror(errno))))
            }
        }
    }

    /// The planned target, or the next free `_n` name if something appeared there since planning.
    private func freeTarget(_ target: URL, source: URL, plan: Plan) -> URL {
        var resolver = TargetResolver(root: plan.root, settings: plan.settingsSnapshot)
        return resolver.reserve(fileName: target.lastPathComponent, in: target.deletingLastPathComponent(), source: source)
    }

    private func newRunID() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = "r-\(formatter.string(from: now()))"
        var id = base
        var counter = 2
        while FileManager.default.fileExists(atPath: directory.runsURL.appending(path: "\(id).jsonl").path) {
            id = "\(base)-\(counter)"
            counter += 1
        }
        return id
    }
}
