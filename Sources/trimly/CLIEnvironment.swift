import Foundation
import TrimlyCore

struct CLIEnvironment {
    let directory: DataDirectory
    let settings: Settings

    var store: PlanStore { PlanStore(directory: directory) }

    func provider() -> OllamaProvider {
        OllamaProvider(
            baseURL: URL(string: settings.providerURL) ?? URL(string: "http://localhost:11434")!,
            timeout: settings.timeoutSeconds,
            keepAlive: settings.keepAlive
        )
    }

    /// Checks that Ollama answers and `model` is installed; returns a Turkish warning otherwise.
    func llmProblem(for model: String) async -> String? {
        let health = await provider().health()
        guard health.reachable else {
            return "Ollama erişilemiyor"
        }
        guard health.availableModels.contains(model) || health.availableModels.contains(model + ":latest") else {
            return "\(model) yüklü değil"
        }
        return nil
    }

    static func absoluteURL(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(filePath: expanded, directoryHint: .isDirectory, relativeTo: .currentDirectory()).absoluteURL.standardizedFileURL
    }
}
