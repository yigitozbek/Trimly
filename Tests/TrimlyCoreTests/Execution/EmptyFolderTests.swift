import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct EmptyFolderTests {
    let fm = FileManager.default

    func fixture(removeEmpty: Bool = true, archive: URL? = nil) throws -> PlannerFixture {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.removeEmptyFolders = removeEmpty
        if let archive {
            f.settings.targetMode = .central
            f.settings.archiveRoot = archive.path
        }
        return f
    }

    /// Plans without the LLM, approves every file that has a target (unless excluded) and applies.
    func apply(_ f: PlannerFixture, files: [String], folders: [String] = [], except excluded: Set<String> = []) async throws {
        for path in folders {
            try fm.createDirectory(at: f.root.appending(path: path), withIntermediateDirectories: true)
        }
        for path in files {
            let url = f.root.appending(path: path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Unique bytes: identical defaults become trash-duplicate candidates and skip bulk approval.
            try TestFS.file(url.lastPathComponent, in: url.deletingLastPathComponent(), contents: path)
        }
        var plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let ids = plan.items.filter { $0.kind == .file && $0.target != nil && excluded.contains($0.relativePath) == false }.map(\.id)
        _ = PlanEditor.setApproval(&plan, itemIDs: Set(ids), approved: true)
        _ = PlanEditor.setApproval(&plan, itemIDs: Set(plan.items.filter { excluded.contains($0.relativePath) }.map(\.id)), approved: false)
        try f.store.save(plan)
        _ = try await Executor(directory: f.data).apply(planID: plan.id)
    }

    func exists(_ f: PlannerFixture, _ path: String) -> Bool {
        fm.fileExists(atPath: f.root.appending(path: path).path)
    }

    @Test func removesFoldersEmptiedByTheRunAndUndoRecreatesThem() async throws {
        let f = try fixture()
        try await apply(f, files: ["Rastgele/alt/a.pdf", "Rastgele/alt/c.jpg", "Rastgele/b.jpg"])
        #expect(exists(f, "Rastgele") == false)
        _ = try await Undoer(directory: f.data).undo(runID: nil)
        #expect(exists(f, "Rastgele/alt/a.pdf") && exists(f, "Rastgele/alt/c.jpg") && exists(f, "Rastgele/b.jpg"))
    }

    @Test func dsStoreOnlyFolderIsRemovedAndNotRestored() async throws {
        let f = try fixture()
        try await apply(f, files: ["Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/.DS_Store"])
        #expect(exists(f, "Rastgele") == false)
        _ = try await Undoer(directory: f.data).undo(runID: nil)
        #expect(exists(f, "Rastgele/a.pdf") && exists(f, "Rastgele/.DS_Store") == false)
    }

    @Test(.tags(.edgeCase)) func preexistingEmptyFoldersAndRootAreLeftAlone() async throws {
        let f = try fixture()
        try await apply(f, files: ["Rastgele/a.pdf", "Rastgele/b.jpg"], folders: ["Bos", "Rastgele/IcBos"])
        #expect(exists(f, "Bos") && exists(f, "Rastgele/IcBos"))

        let archive = try TestFS.tempDir()
        let central = try fixture(archive: archive)
        try await apply(central, files: ["Rastgele/a.pdf", "Rastgele/b.jpg"])
        #expect(exists(central, "Rastgele") == false)
        let rootLeft = try fm.contentsOfDirectory(atPath: central.root.path)
        #expect(exists(central, "") && rootLeft.isEmpty)
    }

    @Test func nonEmptyFolderIsKept() async throws {
        let f = try fixture()
        try await apply(f, files: ["Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/c.dmg"], except: ["Rastgele/c.dmg"])
        #expect(exists(f, "Rastgele/c.dmg"))
    }

    @Test func settingOffKeepsEmptiedFolders() async throws {
        let f = try fixture(removeEmpty: false)
        try await apply(f, files: ["Rastgele/a.pdf", "Rastgele/b.jpg"])
        let left = try fm.contentsOfDirectory(atPath: f.root.appending(path: "Rastgele").path)
        #expect(exists(f, "Rastgele") && left.isEmpty)
    }

    @Test func recoveryResolvesPendingRmdir() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        let gone = try TestFS.tempDir().appending(path: "silinmis")
        let present = try TestFS.tempDir()
        let url = data.runsURL.appending(path: "r-test.jsonl")
        try fm.createDirectory(at: data.runsURL, withIntermediateDirectories: true)
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-test", planID: "p", root: "/", at: Date()))
        let removed = try journal.append(JournalEntry(seq: -1, op: .rmdir, state: .pending, path: gone.path))
        let kept = try journal.append(JournalEntry(seq: -1, op: .rmdir, state: .pending, path: present.path))
        try Recovery.recover(journalAt: url)
        let recovered = try Journal.open(at: url)
        #expect(recovered.effectiveState(of: removed) == .done && recovered.effectiveState(of: kept) == .failed)
    }
}
