import Foundation

/// Replays a run's journal backwards. Skips (and reports) anything that changed since the move;
/// removes only folders Trimly created, and only when empty (a lone Finder `.DS_Store` counts as empty).
/// Undo steps are journaled too, so running it twice is safe and a partial undo can be resumed.
public struct Undoer {
    private let directory: DataDirectory

    public init(directory: DataDirectory) {
        self.directory = directory
    }

    public func undo(runID: String?) throws -> UndoSummary {
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
            if fm.fileExists(atPath: path) == false {
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .done))
                continue
            }
            var contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
            if contents == [".DS_Store"] {
                try fm.removeItem(atPath: (path as NSString).appendingPathComponent(".DS_Store"))
                contents = []
            }
            if contents.isEmpty {
                try fm.removeItem(atPath: path)
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .done))
                removedFolders += 1
            } else {
                try journal.append(JournalEntry(seq: -1, op: .undo, ref: folder.seq, state: .skipped, message: "Klasör boş değil"))
                skipped.append(SkippedEntry(path: path, reason: "Klasör boş değil"))
            }
        }

        let runIDValue = journal.entries.first { $0.type == "header" }?.runID ?? url.deletingPathExtension().lastPathComponent
        return UndoSummary(runID: runIDValue, restored: restored, removedFolders: removedFolders, skipped: skipped)
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
