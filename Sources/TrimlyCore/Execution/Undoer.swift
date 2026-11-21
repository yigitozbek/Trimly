import Foundation

/// Replays a run's journal backwards in one reverse-seq pass (`rmdir`, `tag`, `move`, `mkdir`). Skips (and
/// reports) anything that changed since the run; removes only folders Trimly created, and only when empty (a
/// lone Finder `.DS_Store` counts as empty). Undo steps are journaled too, so running it twice is safe and a
/// partial undo can be resumed.
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
        var restoredTags = 0
        var removedFolders = 0
        var skipped: [SkippedEntry] = []

        let replayable: Set<JournalOp> = [.rmdir, .tag, .move, .mkdir]
        let ops = journal.entries.filter {
            guard let op = $0.op, replayable.contains(op) else { return false }
            return journal.effectiveState(of: $0.seq) == .done
        }
        for entry in ops.reversed() where RunLog.isUndone(entry.seq, in: journal) == false {
            switch entry.op {
            case .rmdir:
                guard let path = entry.path else { continue }
                var isDirectory: ObjCBool = false
                if fm.fileExists(atPath: path, isDirectory: &isDirectory) == false {
                    do {
                        try fm.createDirectory(atPath: path, withIntermediateDirectories: false)
                    } catch {
                        let reason = "Klasör yeniden oluşturulamadı: \(error.localizedDescription)"
                        try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .failed, message: reason))
                        skipped.append(SkippedEntry(path: path, reason: reason))
                        continue
                    }
                } else if isDirectory.boolValue == false {
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: "Klasörün yerinde dosya var"))
                    skipped.append(SkippedEntry(path: path, reason: "Klasörün yerinde dosya var"))
                    continue
                }
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .done))

            case .tag:
                guard let path = entry.path, let written = entry.tags, let previous = entry.previousTags else { continue }
                let fileURL = URL(filePath: path)
                guard fm.fileExists(atPath: path) else {
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: "Dosya bulunamadı"))
                    skipped.append(SkippedEntry(path: path, reason: "Dosya bulunamadı"))
                    continue
                }
                let current: [String]
                do {
                    current = try FinderTags.read(fileURL)
                } catch {
                    try journal.append(JournalEntry(
                        seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: "Etiketler okunamadı"
                    ))
                    skipped.append(SkippedEntry(path: path, reason: "Etiketler okunamadı"))
                    continue
                }
                guard FinderTags.sameSet(current, written) else {
                    try journal.append(JournalEntry(
                        seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: "Etiketler sonradan değişmiş"
                    ))
                    skipped.append(SkippedEntry(path: path, reason: "Etiketler sonradan değişmiş"))
                    continue
                }
                let undoSeq = try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .pending))
                do {
                    try FinderTags.write(previous, to: fileURL)
                    try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .done))
                    restoredTags += 1
                } catch {
                    try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .failed, message: error.localizedDescription))
                    skipped.append(SkippedEntry(path: path, reason: "Etiket geri alınamadı: \(error.localizedDescription)"))
                }

            case .move:
                guard let from = entry.from, let to = entry.to else { continue }
                let reason: String?
                if let current = SourceFingerprint.read(from: URL(filePath: to)) {
                    let journaled = SourceFingerprint(size: entry.size, modifiedAt: entry.mtime ?? .distantPast)
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
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: reason))
                    skipped.append(SkippedEntry(path: to, reason: reason))
                    continue
                }
                let undoSeq = try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .pending))
                do {
                    try fm.moveItem(at: URL(filePath: to), to: URL(filePath: from))
                    try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .done))
                    restored += 1
                } catch {
                    try journal.append(JournalEntry(seq: -1, ref: undoSeq, state: .failed, message: error.localizedDescription))
                    skipped.append(SkippedEntry(path: to, reason: "Geri alma hatası: \(error.localizedDescription)"))
                }

            case .mkdir:
                guard let path = entry.path else { continue }
                let outcome = Self.removeCreatedFolder(at: path)
                switch outcome {
                case .gone:
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .done))
                case .removed:
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .done))
                    removedFolders += 1
                case .kept(let reason):
                    try journal.append(JournalEntry(seq: -1, op: .undo, ref: entry.seq, state: .skipped, message: reason))
                    skipped.append(SkippedEntry(path: path, reason: reason))
                }

            case .trash:
                // Implemented in Task 3.
                continue
            case .undo, nil:
                continue
            }
        }

        let runIDValue = journal.entries.first { $0.type == "header" }?.runID ?? url.deletingPathExtension().lastPathComponent
        return UndoSummary(
            runID: runIDValue,
            restored: restored,
            removedFolders: removedFolders,
            skipped: skipped,
            restoredTags: restoredTags
        )
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
        return errno == ENOTEMPTY || errno == EEXIST
            ? .kept("Klasör boş değil")
            : .kept("Klasör kaldırılamadı: \(String(cString: strerror(errno)))")
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
