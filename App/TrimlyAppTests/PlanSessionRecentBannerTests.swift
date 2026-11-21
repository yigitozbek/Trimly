import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionRecentBannerTests {
    @Test func recentSkipCountReadsSkipReasonPrefix() async throws {
        let f = try AppFixture.empty()
        try f.writeSettings { $0.recentMinutes = 60 }
        let now = Date()
        try TestFS.file("fresh.pdf", in: f.root, contents: "fresh", modified: now, created: now)
        try TestFS.file(
            "old.pdf", in: f.root, contents: "old-bytes",
            modified: now.addingTimeInterval(-7_200), created: now.addingTimeInterval(-7_200)
        )
        let session = PlanSession(root: f.root, environment: f.environment(now: now))
        await session.start()
        #expect(session.recentSkipCount >= 1)
        #expect(try f.item("fresh.pdf", in: session.plan).status == .skipped)
    }

    @Test func recentSkipsDominateWhenMostAreRecent() async throws {
        let f = try AppFixture.empty()
        try f.writeSettings { $0.recentMinutes = 60 }
        let now = Date()
        for index in 0..<5 {
            try TestFS.file("n\(index).pdf", in: f.root, contents: "n\(index)", modified: now, created: now)
        }
        let session = PlanSession(root: f.root, environment: f.environment(now: now))
        await session.start()
        #expect(session.recentSkipCount == 5)
        #expect(session.recentSkipsDominate)
    }
}
