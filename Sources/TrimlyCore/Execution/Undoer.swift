import Foundation

/// Replays a run's journal backwards. Skips (and reports) anything that changed since the move;
/// removes only folders Trimly created, and only when empty (a lone Finder `.DS_Store` counts as empty).
/// Undo steps are journaled too, so running it twice is safe and a partial undo can be resumed.
public struct Undoer: Sendable {
    private let directory: DataDirectory

    public init(directory: DataDirectory) {
        self.directory = directory
    }

    /// `@concurrent`: file moves never run on a caller's main actor. Holds the data-directory lock throughout.
    @concurrent
    public func undo(runID: String?) async throws -> UndoSummary {
        let lock = try DataLock.acquire(in: directory)
        return try withExtendedLifetime(lock) {
            try undoLocked(runID: runID)
        }
    }

    private func undoLocked(runID: String?) throws -> UndoSummary {
        let url = try journalURL(for: runID)
        try Recovery.recover(journalAt: url)
        var journal = try Journal.open(at: url)
        let fm = FileManager.default
        var restored = 0
        var removedFolders = 0
        var skipped: [SkippedEntry] = []

        for move in RunLog.doneMoves(in: journal).reversed() where RunLog.isUndone(move.seq, in: journal) == false {
            guard let from = move.from, let to = move.to else { continue }
            let reason: String?
            if let current = SourceFingerprint.read(from: URL(filePath: to)) {
                let journaled = SourceFingerprint(size: move.size, modifiedAt: move.mtime ?? .distantPast)
                if journaled.matches(current) == false {
                    reason = "Hedef dosya değişmiş"
                } else if fm.fileExists(atPath: from) {
                    reason = "Orijinal konum dolu"
                } else {
                    reason = nil
                }
            } else {
                reason = "Hedefte dosya yok"
            }
            if let reason {
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: move.seq, state: .skipped, message: reason))
                skipped.append(SkippedEntry(path: to, reason: reason))
                continue
            }
            let undoSeq = try journal.append(JournalEntry(seq: -1, op: .undo, ref: move.seq, state: .pending))
            do {
                try fm.moveItem(at: URL(filePath: to), to: URL(filePath: from))
                try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .done))
                restored += 1
            } catch {
                try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .failed, message: error.localizedDescription))
                skipped.append(SkippedEntry(path: to, reason: "Geri alma hatası: \(error.localizedDescription)"))
            }
        }

        let createdFolders = journal.entries.filter { $0.op == .mkdir && journal.effectiveState(of: $0.seq) == .done }
        for folder in createdFolders.reversed() where RunLog.isUndone(folder.seq, in: journal) == false {
            guard let path = folder.path else { continue }
            let outcome = Self.removeCreatedFolder(at: path)
            switch outcome {
            case .gone:
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .done))
            case .removed:
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .done))
                removedFolders += 1
            case .kept(let reason):
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .skipped, message: reason))
                skipped.append(SkippedEntry(path: path, reason: reason))
            }
        }

        let runIDValue = journal.entries.first { $0.type == "header" }?.runID ?? url.deletingPathExtension().lastPathComponent
        return UndoSummary(runID: runIDValue, restored: restored, removedFolders: removedFolders, skipped: skipped)
    }

    private enum FolderOutcome {
        case gone
        case removed
        case kept(String)
    }

    /// Never deletes user data: only a real directory (lstat, symlinks excluded) is touched, a lone `.DS_Store`
    /// is unlinked only if it is a regular file, and `rmdir(2)` refuses anything that is not empty.
    private static func removeCreatedFolder(at path: String) -> FolderOutcome {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            return .gone
        }
        guard info.st_mode & S_IFMT == S_IFDIR else {
            return .kept("Klasör değil")
        }
        let dsStore = (path as NSString).appendingPathComponent(".DS_Store")
        if (try? FileManager.default.contentsOfDirectory(atPath: path)) == [".DS_Store"] {
            var dsInfo = stat()
            if lstat(dsStore, &dsInfo) == 0, dsInfo.st_mode & S_IFMT == S_IFREG {
                unlink(dsStore)
            }
        }
        if rmdir(path) == 0 {
            return .removed
        }
        return errno == ENOTEMPTY || errno == EEXIST ? .kept("Klasör boş değil") : .kept("Klasör kaldırılamadı: \(String(cString: strerror(errno)))")
    }

    private func journalURL(for runID: String?) throws -> URL {
        if let runID {
            let url = directory.runsURL.appending(path: "\(runID).jsonl")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw UndoError.runNotFound(runID)
            }
            return url
        }
        guard let latest = try RunLog.list(in: directory).first(where: { $0.undone == false }) else {
            throw UndoError.noRuns
        }
        return directory.runsURL.appending(path: "\(latest.runID).jsonl")
    }
}
