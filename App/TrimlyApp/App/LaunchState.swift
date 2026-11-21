import Observation

/// Whether this launch came from a `trimly://` link; the start window uses it to step aside for the plan window.
@MainActor
@Observable
final class LaunchState {
    static let shared = LaunchState()
    var launchedByURL = false
}
