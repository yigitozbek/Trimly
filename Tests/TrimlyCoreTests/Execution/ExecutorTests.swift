import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct ExecutorTests {
    let shotName = "Screenshot 2025-03-14 at 10.22.31.png"

    func journal(_ f: PlannerFixture, _ runID: String) throws -> Journal {
        try Journal.open(at: f.data.runsURL.appending(path: "\(runID).jsonl"))
    }

    @Test func appliesApprovedOnly() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let target = try #require(plan.item(shotName).target)

        let summary = try await Executor(directory: f.data).apply(planID: plan.id)

        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(FileManager.default.fileExists(atPath: f.root.appending(path: shotName).path) == false)
        #expect(FileManager.default.fileExists(atPath: f.root.appending(path: "download (3).pdf").path))
        #expect(summary.moved == 2 && summary.failed.isEmpty)
        let entries = try journal(f, summary.runID).entries
        #expect(entries.contains { $0.op == .mkdir && $0.path == f.root.appending(path: "Ekran-Goruntuleri").path })
        let move = try #require(entries.first { $0.op == .move && $0.to == target.path })
        #expect(try journal(f, summary.runID).effectiveState(of: move.seq) == .done)
        let saved = try f.store.load(id: plan.id)
        #expect(saved.state == .applied && saved.appliedRunID == summary.runID)
    }

    @Test func refusesAppliedPlan() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        _ = try await Executor(directory: f.data).apply(planID: plan.id)
        await #expect(throws: ExecutionError.alreadyApplied) {
            try await Executor(directory: f.data).apply(planID: plan.id)
        }
    }

    @Test func skipsChangedSource() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let source = f.root.appending(path: shotName)
        try Data("degisti".utf8).write(to: source)
        let summary = try await Executor(directory: f.data).apply(planID: plan.id)
        #expect(summary.skipped.contains(SkippedEntry(path: source.path, reason: "Kaynak değişmiş")))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func skipsMissingSource() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let source = f.root.appending(path: shotName)
        try FileManager.default.removeItem(at: source)
        let summary = try await Executor(directory: f.data).apply(planID: plan.id)
        #expect(summary.skipped.contains(SkippedEntry(path: source.path, reason: "Kaynak bulunamadı")))
    }

    @Test func neverOverwritesExistingTarget() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let target = try #require(plan.item(shotName).target)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("orijinal".utf8).write(to: target)

        _ = try await Executor(directory: f.data).apply(planID: plan.id)

        #expect(try String(contentsOf: target, encoding: .utf8) == "orijinal")
        let suffixed = target.deletingLastPathComponent().appending(path: "2025-03-14_Ekran-Goruntusu_10-22-31_2.png")
        #expect(FileManager.default.fileExists(atPath: suffixed.path))
    }

    @Test func movesApprovedFolderWithContents() async throws {
        let f = try PlannerFixture()
        let picks = try TestFS.folder("secilenler", in: f.root.appending(path: "Album"))
        try TestFS.file("1.jpg", in: picks)
        var plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        _ = PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: true)
        try f.store.save(plan)
        let target = try #require(plan.item("Album").target)

        let summary = try await Executor(directory: f.data).apply(planID: plan.id)

        #expect(FileManager.default.fileExists(atPath: target.appending(path: "p0.jpg").path))
        #expect(FileManager.default.fileExists(atPath: target.appending(path: "secilenler/1.jpg").path))
        let albumMoves = try journal(f, summary.runID).entries.filter { $0.op == .move && $0.from?.hasPrefix(f.root.appending(path: "Album").path) == true }
        #expect(albumMoves.count == 1)
    }

    @Test(.tags(.edgeCase)) func rerunAfterApplyFindsNothing() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        _ = try await Executor(directory: f.data).apply(planID: plan.id)
        let again = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(again.id != plan.id)
        #expect(again.items.contains { $0.approved } == false)
        #expect(again.item("Ekran-Goruntuleri").skipReason == "Trimly kategori klasörü (içi düzenlenir)")
        #expect(again.item("Ekran-Goruntuleri").folderMode == .distribute)
    }

    @Test func recoveryMarksPendingMoves() throws {
        let dir = try TestFS.tempDir()
        let movedTarget = try TestFS.file("moved.txt", in: dir)
        let stuckSource = try TestFS.file("stuck.txt", in: dir)
        let url = dir.appending(path: "r.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-x"))
        let completed = try journal.append(JournalEntry(seq: -1, op: .move, state: .pending, from: dir.appending(path: "orig.txt").path, to: movedTarget.path))
        let interrupted = try journal.append(JournalEntry(seq: -1, op: .move, state: .pending, from: stuckSource.path, to: dir.appending(path: "nowhere.txt").path))

        #expect(try Recovery.recover(journalAt: url) == 2)
        let reopened = try Journal.open(at: url)
        #expect(reopened.effectiveState(of: completed) == .done)
        #expect(reopened.effectiveState(of: interrupted) == .failed)
    }
}
