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

    @Test(.tags(.edgeCase)) func tornLastLineIsIgnoredAndNextAppendStartsOnNewLine() throws {
        let url = try TestFS.tempDir().appending(path: "r.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-1"))
        let move = try journal.append(JournalEntry(seq: -1, op: .move, state: .pending, from: "/a", to: "/b"))
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"ref":1,"se"#.utf8))
        try handle.close()

        var reopened = try Journal.open(at: url)
        #expect(reopened.entries.count == 2)
        try reopened.append(JournalEntry(seq: -1, ref: move, state: .done))
        let again = try Journal.open(at: url)
        #expect(again.entries.count == 3)
        #expect(again.effectiveState(of: move) == .done)
    }

    @Test func recoverAllSkipsUnreadableJournals() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        try data.ensureExists()
        try Data("bozuk".utf8).write(to: data.runsURL.appending(path: "r-bozuk.jsonl"))
        #expect(throws: Never.self) { try Recovery.recoverAll(in: data) }
    }

    @Test func omitsNilFields() throws {
        let url = try TestFS.tempDir().appending(path: "r.jsonl")
        _ = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-1"))
        let line = try String(contentsOf: url, encoding: .utf8)
        #expect(line.contains("\"from\"") == false)
    }
}
