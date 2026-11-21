import Foundation
import TrimlyCore

/// Dependencies of the app's view models; tests swap in a temporary data directory, a mock LLM and a fixed clock.
struct AppEnvironment: Sendable {
    let directory: DataDirectory
    let makeProvider: @Sendable (Settings) -> any LLMProvider
    let now: @Sendable () -> Date

    /// `TRIMLY_DATA_DIR` overrides the data directory (manual testing without touching the real one).
    static let live = AppEnvironment(
        directory: ProcessInfo.processInfo.environment["TRIMLY_DATA_DIR"].map { DataDirectory(root: URL(filePath: $0, directoryHint: .isDirectory)) } ?? .default,
        makeProvider: { settings in
            OllamaProvider(
                baseURL: URL(string: settings.providerURL) ?? URL(string: "http://localhost:11434")!,
                timeout: settings.timeoutSeconds,
                keepAlive: settings.keepAlive
            )
        },
        now: { Date() }
    )

    /// Current settings, or defaults when the file is missing or unreadable.
    func loadSettings() -> Settings {
        (try? SettingsStore.load(from: directory)) ?? Settings()
    }
}
