import Foundation
import Observation

/// Detects a launch caused by a `trimly://` link so the start window can step aside for the plan window.
/// Only a link that arrives within a few seconds of launch counts; later links (Dock menu, Finder) never
/// close the start window.
@MainActor
@Observable
final class LaunchState {
    static let shared = LaunchState(launchedAt: Date())
    private static let launchWindow: TimeInterval = 3

    private let launchedAt: Date
    private(set) var launchedByURL = false

    init(launchedAt: Date) {
        self.launchedAt = launchedAt
    }

    func noteURLOpen(at date: Date = Date()) {
        if date.timeIntervalSince(launchedAt) < Self.launchWindow {
            launchedByURL = true
        }
    }
}
