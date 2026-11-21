import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct TrashExecutionTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }

    func candidateFixture() async throws -> (PlannerFixture, Plan, PlanItem) {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.recentMinutes = 0
        try TestFS.file("Setup.dmg", in: f.root, contents: "installer", modified: daysAgo(40), created: daysAgo(40))
        let plan = try await f.planner(nil, now: now).makePlan(root: f.root, useLLM: false)
        let item = plan.item("Setup.dmg")
        #expect(item.trashReason == .oldInstaller(days: 30))
        return (f, plan, item)
    }

    @Test func trashMovesToTrashAndUndoRestores() async throws {
        let (f, plan, item) = try await candidateFixture()
        let summary = try await Executor(directory: f.data).trash(planID: plan.id, itemID: item.id)
        #expect(summary.trashed == 1 && summary.moved == 0)
        #expect(FileManager.default.fileExists(atPath: item.source.path) == false)
        let updated = try f.store.load(id: plan.id)
        #expect(updated.state == .ready)
        #expect(updated.item("Setup.dmg").trashedRunID == summary.runID)
        let undo = try await Undoer(directory: f.data).undo(runID: summary.runID)
        #expect(undo.restored == 1)
        #expect(FileManager.default.fileExists(atPath: item.source.path))
    }

    @Test(.tags(.edgeCase)) func undoReportsEmptiedTrash() async throws {
        let (f, plan, item) = try await candidateFixture()
        let summary = try await Executor(directory: f.data).trash(planID: plan.id, itemID: item.id)
        let journal = try Journal.open(at: f.data.runsURL.appending(path: "\(summary.runID).jsonl"))
        let trash = try #require(journal.entries.first { $0.op == .trash })
        let trashURL = URL(filePath: try #require(trash.to))
        try FileManager.default.removeItem(at: trashURL)
        let undo = try await Undoer(directory: f.data).undo(runID: summary.runID)
        #expect(undo.restored == 0)
        #expect(undo.skipped.contains { $0.reason == "Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)" })
    }

    @Test(.tags(.edgeCase)) func trashRejectsCritical() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.recentMinutes = 0
        try TestFS.file("kimlik.pdf", in: f.root, contents: "TC", modified: daysAgo(40), created: daysAgo(40))
        let plan = try await f.planner(nil, now: now).makePlan(root: f.root, useLLM: false)
        let item = plan.item("kimlik.pdf")
        await #expect(throws: ExecutionError.notTrashCandidate) {
            try await Executor(directory: f.data).trash(planID: plan.id, itemID: item.id)
        }
    }

    @Test(.tags(.edgeCase)) func trashRejectsNonCandidate() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.recentMinutes = 0
        try TestFS.file("note.txt", in: f.root, contents: "hello", modified: daysAgo(1), created: daysAgo(1))
        let plan = try await f.planner(nil, now: now).makePlan(root: f.root, useLLM: false)
        let item = plan.item("note.txt")
        #expect(item.trashReason == nil)
        await #expect(throws: ExecutionError.notTrashCandidate) {
            try await Executor(directory: f.data).trash(planID: plan.id, itemID: item.id)
        }
    }

    @Test func trashRunIsListedSeparately() async throws {
        let (f, plan, item) = try await candidateFixture()
        let summary = try await Executor(directory: f.data).trash(planID: plan.id, itemID: item.id)
        let run = try #require(try RunLog.list(in: f.data).first)
        #expect(run.runID == summary.runID && run.trashed == 1 && run.undone == false)
        #expect(run.title == "Çöp: Setup.dmg")
        _ = try await Undoer(directory: f.data).undo(runID: summary.runID)
        #expect(try RunLog.list(in: f.data).first?.undone == true)
    }

    @Test func recoveryResolvesPendingTrash() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        let dir = try TestFS.tempDir()
        let source = try TestFS.file("a.dmg", in: dir)
        let inTrash = try TestFS.file("a.dmg", in: try TestFS.tempDir())
        try FileManager.default.createDirectory(at: data.runsURL, withIntermediateDirectories: true)
        let url = data.runsURL.appending(path: "r-trash.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-trash", planID: "p", root: "/", at: Date()))
        let done = try journal.append(JournalEntry(seq: -1, op: .trash, state: .pending, from: source.path, to: inTrash.path))
        let missing = try TestFS.tempDir().appending(path: "gone.dmg").path
        let failed = try journal.append(JournalEntry(seq: -1, op: .trash, state: .pending, from: "/tmp/x", to: missing))
        try Recovery.recover(journalAt: url)
        let recovered = try Journal.open(at: url)
        #expect(recovered.effectiveState(of: done) == .done && recovered.effectiveState(of: failed) == .failed)
    }
}
