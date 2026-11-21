import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionTagTests {
    func tagOnlySession(_ f: AppFixture) async throws -> PlanSession {
        try f.writeSettings { $0.targetMode = .tagOnly }
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        return session
    }

    @Test func tagOnlyPlanIsApprovableAndSummarized() async throws {
        let f = try AppFixture.empty()
        try TestFS.file("fatura-ocak.pdf", in: f.root)
        let session = try await tagOnlySession(f)
        let summary = session.applySummary
        #expect(summary.isTagOnly)
        #expect(summary.count == session.approvedCount)
        #expect(summary.count >= 1)
        #expect(try f.item("fatura-ocak.pdf", in: session.plan).target == nil)
        #expect(try f.item("fatura-ocak.pdf", in: session.plan).tagsToAdd == ["Fatura"])
    }

    @Test func tagOnlyApplyAndUndoRestoreTags() async throws {
        let f = try AppFixture.empty()
        let file = try TestFS.file("fatura-ocak.pdf", in: f.root)
        let session = try await tagOnlySession(f)
        await session.apply(confirming: session.applySummary)
        #expect(session.lastRun?.moved == 0 && session.lastRun?.tagged == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(FinderTags.read(file) == ["Fatura"])
        await session.undoLastApply()
        #expect(session.lastUndo?.restoredTags == 1)
        #expect(FinderTags.read(file).isEmpty)
    }

    @Test func selectAllUsesTagActions() async throws {
        let f = try AppFixture.empty()
        try TestFS.file("download (3).pdf", in: f.root, contents: "Fatura No 123")
        let session = try await tagOnlySession(f)
        let item = try f.item("download (3).pdf", in: session.plan)
        #expect(item.target == nil && item.tagsToAdd.isEmpty == false)
        #expect(item.approved == false)
        #expect(session.selectablePendingCount >= 1)
        session.setPendingApproved(true)
        #expect(try f.item("download (3).pdf", in: session.plan).approved)
    }
}
