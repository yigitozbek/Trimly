import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct JournalTests {
    @Test func appendsAndReadsBack() throws {
        let url = try TestFS.tempDir().appending(path: "r.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-1"))
        let seq = try journal.append(JournalEntry(seq: -1, op: .move, state: .pending, from: "/a", to: "/b"))
        try journal.append(JournalEntry(seq: -1, ref: seq, state: .done))
        #expect(journal.effectiveState(of: seq) == .done)
        let reopened = try Journal.open(at: url)
        #expect(reopened.entries == journal.entries)
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines.allSatisfy { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) != nil })
    }

    @Test func omitsNilFields() throws {
        let url = try TestFS.tempDir().appending(path: "r.jsonl")
        _ = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-1"))
        let line = try String(contentsOf: url, encoding: .utf8)
        #expect(line.contains("\"from\"") == false)
    }
}
