import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionTrashTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }

    func trashSession(_ f: AppFixture) async throws -> PlanSession {
        try f.writeSettings { $0.recentMinutes = 0 }
        let session = PlanSession(root: f.root, environment: f.environment(now: now))
        await session.start()
        return session
    }

    @Test func trashCandidateAppearsInSection() async throws {
        let f = try AppFixture.empty()
        try TestFS.file("Setup.dmg", in: f.root, contents: "installer", modified: daysAgo(40), created: daysAgo(40))
        let session = try await trashSession(f)
        #expect(session.trashCandidates.contains { $0.name == "Setup.dmg" })
        #expect(try f.item("Setup.dmg", in: session.plan).trashReason == .oldInstaller(days: 30))
    }

    @Test func trashAndUndoFromSession() async throws {
        let f = try AppFixture.empty()
        let file = try TestFS.file("Setup.dmg", in: f.root, contents: "installer", modified: daysAgo(40), created: daysAgo(40))
        let session = try await trashSession(f)
        let item = try f.item("Setup.dmg", in: session.plan)
        await session.trash(item)
        #expect(session.lastRun?.trashed == 1)
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
        let runID = try #require(session.lastRun?.runID)
        await session.undoTrash(runID: runID)
        #expect(session.lastUndo?.restored == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
