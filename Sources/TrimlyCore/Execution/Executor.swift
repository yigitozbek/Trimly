import Foundation

/// Applies the approved items of a plan. Moves only (`FileManager.moveItem`, which refuses to overwrite),
/// each one journaled `pending` → move → `done`, so every run can be undone.
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
        var movedSources: [URL] = []
        var skipped: [SkippedEntry] = []
        var failed: [SkippedEntry] = []

        for item in plan.items where item.approved && item.status != .skipped {
            guard let plannedTarget = item.target else {
                skipped.append(SkippedEntry(path: item.source.path, reason: "Hedef yok"))
                continue
            }
            guard let current = SourceFingerprint.read(from: item.source) else {
                skipped.append(SkippedEntry(path: item.source.path, reason: "Kaynak bulunamadı"))
                continue
            }
            guard item.sourceFingerprint.matches(current) else {
                skipped.append(SkippedEntry(path: item.source.path, reason: "Kaynak değişmiş"))
                continue
            }
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
                } catch {
                    try journal.append(JournalEntry(seq: -1, ref: seq, state: .failed, message: error.localizedDescription))
                    failed.append(SkippedEntry(path: item.source.path, reason: "Taşıma hatası: \(error.localizedDescription)"))
                }
            } catch {
                failed.append(SkippedEntry(path: item.source.path, reason: "Taşıma hatası: \(error.localizedDescription)"))
            }
        }

        if plan.settingsSnapshot.removeEmptyFolders {
            try removeEmptiedFolders(after: movedSources, root: plan.root, journal: &journal)
        }

        plan.state = .applied
        plan.appliedRunID = runID
        try store.save(plan)
        return RunSummary(runID: runID, moved: moved, skipped: skipped, failed: failed)
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
