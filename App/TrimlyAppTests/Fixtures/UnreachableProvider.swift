import TrimlyCore

/// Default test provider: behaves like a stopped Ollama so tests never reach a real one.
struct UnreachableProvider: LLMProvider {
    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        throw LLMError.unreachable
    }

    func unload(model: String) async {}

    func health() async -> ProviderHealth {
        ProviderHealth(reachable: false, availableModels: [])
    }
}
