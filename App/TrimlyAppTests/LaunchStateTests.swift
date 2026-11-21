import Foundation
import Testing
@testable import TrimlyApp

@MainActor
struct LaunchStateTests {
    @Test func urlRightAfterLaunchCountsAsURLLaunch() {
        let launchedAt = Date()
        let state = LaunchState(launchedAt: launchedAt)
        state.noteURLOpen(at: launchedAt.addingTimeInterval(1))
        #expect(state.launchedByURL)
    }

    @Test(.tags(.edgeCase)) func laterURLDoesNotCloseTheStartWindow() {
        let launchedAt = Date()
        let state = LaunchState(launchedAt: launchedAt)
        state.noteURLOpen(at: launchedAt.addingTimeInterval(30))
        #expect(state.launchedByURL == false)
    }
}
