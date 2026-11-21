import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct DataLockTests {
    @Test func secondAcquireIsBusyUntilReleased() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        try data.ensureExists()
        var first: DataLock? = try DataLock.acquire(in: data)
        #expect(first != nil)
        #expect(throws: DataLockError.busy) { _ = try DataLock.acquire(in: data) }
        first = nil
        #expect(throws: Never.self) { _ = try DataLock.acquire(in: data) }
    }

    @Test func applyAndUndoFailWhileLocked() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let lock = try DataLock.acquire(in: f.data)
        await #expect(throws: DataLockError.busy) { try await Executor(directory: f.data).apply(planID: plan.id) }
        await #expect(throws: DataLockError.busy) { try await Undoer(directory: f.data).undo(runID: nil) }
        withExtendedLifetime(lock) {}
    }

    @Test func recoverAllSkipsWhileLocked() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        try data.ensureExists()
        let dir = try TestFS.tempDir()
        let moved = try TestFS.file("moved.txt", in: dir)
        let url = data.runsURL.appending(path: "r-x.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-x"))
        let seq = try journal.append(JournalEntry(seq: -1, op: .move, state: .pending, from: dir.appending(path: "orig.txt").path, to: moved.path))

        var lock: DataLock? = try DataLock.acquire(in: data)
        #expect(try Recovery.recoverAll(in: data) == 0)
        #expect(try Journal.open(at: url).effectiveState(of: seq) == .pending)
        withExtendedLifetime(lock) {}
        lock = nil
        #expect(try Recovery.recoverAll(in: data) == 1)
        #expect(try Journal.open(at: url).effectiveState(of: seq) == .done)
    }
}
