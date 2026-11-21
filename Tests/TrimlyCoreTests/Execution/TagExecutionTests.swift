import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct TagExecutionTests {
    func fixture(tagOnly: Bool = false) throws -> PlannerFixture {
        var f = try PlannerFixture(standardFiles: false)
        if tagOnly {
            f.settings.targetMode = .tagOnly
        }
        return f
    }

    /// Plans `fatura-ocak.pdf` (decisive invoice rule, approved by default) and applies the plan.
    func apply(_ f: PlannerFixture, tags: [String] = []) async throws -> (item: PlanItem, summary: RunSummary) {
        let file = try TestFS.file("fatura-ocak.pdf", in: f.root)
        try TestFS.setTags(tags, on: file)
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let item = plan.item("fatura-ocak.pdf")
        #expect(item.approved && item.tagsToAdd == ["Fatura"])
        return (item, try await Executor(directory: f.data).apply(planID: plan.id))
    }

    @Test func moveAddsTagAndUndoRestoresPreviousTags() async throws {
        let f = try fixture()
        let (item, summary) = try await apply(f, tags: ["Proje X"])
        let target = try #require(item.target)
        #expect(summary.moved == 1 && summary.tagged == 1)
        #expect(try FinderTags.read(target) == ["Proje X", "Fatura"])
        let undo = try await Undoer(directory: f.data).undo(runID: nil)
        #expect(undo.restored == 1 && undo.restoredTags == 1)
        #expect(try FinderTags.read(item.source) == ["Proje X"])
    }

    @Test func tagOnlyTagsInPlaceAndUndoes() async throws {
        let f = try fixture(tagOnly: true)
        let (item, summary) = try await apply(f)
        #expect(summary.moved == 0 && summary.tagged == 1)
        #expect(try FinderTags.read(item.source) == ["Fatura"])
        _ = try await Undoer(directory: f.data).undo(runID: nil)
        #expect(try FinderTags.read(item.source).isEmpty)
    }

    @Test(.tags(.edgeCase)) func undoKeepsTagsTheUserChangedSince() async throws {
        let f = try fixture()
        let (item, _) = try await apply(f)
        try TestFS.setTags(["Benim"], on: try #require(item.target))
        let undo = try await Undoer(directory: f.data).undo(runID: nil)
        #expect(undo.restored == 1 && FileManager.default.fileExists(atPath: item.source.path))
        #expect(try FinderTags.read(item.source) == ["Benim"])
        #expect(undo.skipped.contains { $0.reason == "Etiketler sonradan değişmiş" })
    }

    @Test(.tags(.edgeCase)) func tagOnlyRunIsUndoable() async throws {
        let f = try fixture(tagOnly: true)
        _ = try await apply(f)
        let run = try #require(try RunLog.list(in: f.data).first)
        #expect(run.undone == false && run.tagged == 1)
        #expect(try await Undoer(directory: f.data).undo(runID: nil).restoredTags == 1)
        #expect(try RunLog.list(in: f.data).first?.undone == true)
    }

    @Test func recoveryResolvesPendingTag() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        let dir = try TestFS.tempDir()
        let written = try TestFS.file("a.pdf", in: dir)
        try TestFS.setTags(["A"], on: written)
        let notWritten = try TestFS.file("b.pdf", in: dir)
        let restored = try TestFS.file("c.pdf", in: dir)
        try FileManager.default.createDirectory(at: data.runsURL, withIntermediateDirectories: true)
        let url = data.runsURL.appending(path: "r-test.jsonl")
        var journal = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-test", planID: "p", root: "/", at: Date()))
        let done = try journal.append(JournalEntry(seq: -1, op: .tag, state: .pending, path: written.path, tags: ["A"], previousTags: []))
        let failed = try journal.append(JournalEntry(seq: -1, op: .tag, state: .pending, path: notWritten.path, tags: ["B"], previousTags: []))
        let tagged = try journal.append(JournalEntry(seq: -1, op: .tag, state: .done, path: restored.path, tags: ["C"], previousTags: []))
        let undone = try journal.append(JournalEntry(seq: -1, op: .undo, ref: tagged, state: .pending))
        try Recovery.recover(journalAt: url)
        let recovered = try Journal.open(at: url)
        #expect(recovered.effectiveState(of: done) == .done && recovered.effectiveState(of: failed) == .failed)
        #expect(recovered.effectiveState(of: undone) == .done)
    }

    /// `resourceValues` can return nil under EACCES; treating that as `[]` would journal empty `previousTags`
    /// and replace real tags if a later write succeeded.
    @Test(.tags(.edgeCase)) func readThrowsWhenTagsUnreadable() throws {
        let file = try TestFS.file("a.pdf", in: try TestFS.tempDir())
        try TestFS.setTags(["Keep"], on: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        #expect(throws: (any Error).self) {
            try FinderTags.read(file)
        }
    }

    @Test(.tags(.edgeCase)) func unreadableTagsAreNotReplacedOnApply() async throws {
        let f = try fixture(tagOnly: true)
        let file = try TestFS.file("fatura-ocak.pdf", in: f.root)
        try TestFS.setTags(["Keep"], on: file)
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item("fatura-ocak.pdf").tagsToAdd == ["Fatura"])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        let summary = try await Executor(directory: f.data).apply(planID: plan.id)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect(summary.tagged == 0)
        #expect(summary.failed.contains { $0.path == file.path && $0.reason.contains("Etiket") })
        #expect(try FinderTags.read(file) == ["Keep"])
    }

    @Test(.tags(.edgeCase)) func failedTagWriteRestoresPreviousTags() async throws {
        let f = try fixture(tagOnly: true)
        let file = try TestFS.file("fatura-ocak.pdf", in: f.root)
        try TestFS.setTags(["Keep"], on: file)
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        var st = stat()
        #expect(lstat(file.path, &st) == 0)
        st.st_flags |= UInt32(UF_IMMUTABLE)
        #expect(chflags(file.path, st.st_flags) == 0)
        defer {
            st.st_flags &= ~UInt32(UF_IMMUTABLE)
            _ = chflags(file.path, st.st_flags)
        }
        let summary = try await Executor(directory: f.data).apply(planID: plan.id)
        #expect(summary.tagged == 0 && summary.failed.isEmpty == false)
        #expect(try FinderTags.read(file) == ["Keep"])
    }
}
