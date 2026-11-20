import Foundation

public enum RunLog {
    /// Every run in the data directory, newest first.
    public static func list(in directory: DataDirectory) throws -> [RunInfo] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.runsURL.path)) ?? []
        return names
            .filter { $0.hasSuffix(".jsonl") }
            .compactMap { try? Journal.open(at: directory.runsURL.appending(path: $0)) }
            .compactMap(info(for:))
            .sorted { ($0.at, $0.runID) > ($1.at, $1.runID) }
    }

    static func info(for journal: Journal) -> RunInfo? {
        guard let header = journal.entries.first(where: { $0.type == "header" }), let runID = header.runID else {
            return nil
        }
        let moves = doneMoves(in: journal)
        return RunInfo(
            runID: runID,
            planID: header.planID ?? "",
            root: header.root ?? "",
            at: header.at ?? .distantPast,
            moved: moves.count,
            undone: moves.allSatisfy { isUndone($0.seq, in: journal) }
        )
    }

    static func doneMoves(in journal: Journal) -> [JournalEntry] {
        journal.entries.filter { $0.op == .move && journal.effectiveState(of: $0.seq) == .done }
    }

    /// True when an `undo` line for `seq` has reached `done`.
    static func isUndone(_ seq: Int, in journal: Journal) -> Bool {
        journal.entries.contains { $0.op == .undo && $0.ref == seq && journal.effectiveState(of: $0.seq) == .done }
    }
}
