import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct UndoerTests {
    let shotName = "Screenshot 2025-03-14 at 10.22.31.png"
    let fm = FileManager.default

    func applied(_ f: PlannerFixture, approveFolders: Bool = false) async throws -> (plan: Plan, run: RunSummary) {
        var plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        if approveFolders {
            _ = PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: true)
            try f.store.save(plan)
        }
        return (plan, try Executor(directory: f.data).apply(planID: plan.id))
    }

    @Test func undoRestoresAndRemovesCreatedFolders() async throws {
        let f = try PlannerFixture()
        _ = try await applied(f)
        let summary = try Undoer(directory: f.data).undo(runID: nil)
        #expect(summary.restored == 2 && summary.removedFolders == 2 && summary.skipped.isEmpty)
        #expect(fm.fileExists(atPath: f.root.appending(path: shotName).path))
        #expect(fm.fileExists(atPath: f.root.appending(path: "song.mp3").path))
        #expect(fm.fileExists(atPath: f.root.appending(path: "Ekran-Goruntuleri").path) == false)
    }

    @Test func undoKeepsFolderWithForeignFiles() async throws {
        let f = try PlannerFixture()
        _ = try await applied(f)
        let folder = f.root.appending(path: "Ekran-Goruntuleri")
        try TestFS.file("yabanci.txt", in: folder)
        let summary = try Undoer(directory: f.data).undo(runID: nil)
        #expect(fm.fileExists(atPath: folder.path))
        #expect(summary.skipped.contains(SkippedEntry(path: folder.path, reason: "Klasör boş değil")))
    }

    @Test(.tags(.edgeCase)) func undoTreatsDSStoreOnlyFolderAsEmpty() async throws {
        let f = try PlannerFixture()
        _ = try await applied(f)
        let folder = f.root.appending(path: "Ekran-Goruntuleri")
        try TestFS.file(".DS_Store", in: folder)
        _ = try Undoer(directory: f.data).undo(runID: nil)
        #expect(fm.fileExists(atPath: folder.path) == false)
    }

    @Test func undoSkipsWhenTargetChanged() async throws {
        let f = try PlannerFixture()
        let (plan, _) = try await applied(f)
        let target = try #require(plan.item(shotName).target)
        try Data("degisti ve uzadi".utf8).write(to: target)
        let summary = try Undoer(directory: f.data).undo(runID: nil)
        #expect(summary.skipped.contains(SkippedEntry(path: target.path, reason: "Hedef dosya değişmiş")))
        #expect(fm.fileExists(atPath: target.path))
    }

    @Test func undoSkipsWhenOriginalOccupied() async throws {
        let f = try PlannerFixture()
        let (plan, _) = try await applied(f)
        let target = try #require(plan.item(shotName).target)
        try TestFS.file(shotName, in: f.root, contents: "yeni")
        let summary = try Undoer(directory: f.data).undo(runID: nil)
        #expect(summary.skipped.contains(SkippedEntry(path: target.path, reason: "Orijinal konum dolu")))
        #expect(try String(contentsOf: f.root.appending(path: shotName), encoding: .utf8) == "yeni")
    }

    @Test func undoIsIdempotent() async throws {
        let f = try PlannerFixture()
        let (_, run) = try await applied(f)
        _ = try Undoer(directory: f.data).undo(runID: run.runID)
        let second = try Undoer(directory: f.data).undo(runID: run.runID)
        #expect(second.restored == 0 && second.removedFolders == 0)
    }

    @Test func undoRestoresFolderWithContents() async throws {
        let f = try PlannerFixture()
        let picks = try TestFS.folder("secilenler", in: f.root.appending(path: "Album"))
        try TestFS.file("1.jpg", in: picks)
        let (plan, _) = try await applied(f, approveFolders: true)
        let categoryFolder = try #require(plan.item("Album").target).deletingLastPathComponent()
        _ = try Undoer(directory: f.data).undo(runID: nil)
        #expect(fm.fileExists(atPath: f.root.appending(path: "Album/p0.jpg").path))
        #expect(fm.fileExists(atPath: f.root.appending(path: "Album/secilenler/1.jpg").path))
        #expect(fm.fileExists(atPath: categoryFolder.path) == false)
    }

    @Test func undoDefaultsToLatestRunAndRunLogListsNewestFirst() async throws {
        let f = try PlannerFixture()
        let (plan1, run1) = try await applied(f)
        let root2 = try TestFS.tempDir()
        try TestFS.file("IMG_0001.HEIC", in: root2)
        let plan2 = try await f.planner(nil).makePlan(root: root2, useLLM: false)
        let run2 = try Executor(directory: f.data, now: { Date().addingTimeInterval(5) }).apply(planID: plan2.id)

        let listed = try RunLog.list(in: f.data)
        #expect(listed.map(\.runID) == [run2.runID, run1.runID])
        #expect(listed.map(\.moved) == [1, 2])

        let summary = try Undoer(directory: f.data).undo(runID: nil)
        #expect(summary.runID == run2.runID)
        #expect(fm.fileExists(atPath: root2.appending(path: "IMG_0001.HEIC").path))
        #expect(fm.fileExists(atPath: try #require(plan1.item(shotName).target).path))
        #expect(try RunLog.list(in: f.data).first?.undone == true)
    }

    @Test func undoErrors() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        #expect(throws: UndoError.noRuns) {
            try Undoer(directory: data).undo(runID: nil)
        }
        #expect(throws: UndoError.runNotFound("r-yok")) {
            try Undoer(directory: data).undo(runID: "r-yok")
        }
    }
}
