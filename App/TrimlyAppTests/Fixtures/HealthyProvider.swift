import TrimlyCore

/// Wraps a scripted provider and reports a healthy Ollama with both default models installed.
struct HealthyProvider: LLMProvider {
    private let wrapped: any LLMProvider

    init(wrapping wrapped: any LLMProvider) {
        self.wrapped = wrapped
    }

    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        try await wrapped.classify(request, model: model)
    }

    func unload(model: String) async {
        await wrapped.unload(model: model)
    }

    func health() async -> ProviderHealth {
        ProviderHealth(reachable: true, availableModels: ["qwen3:4b", "ministral-3:14b"])
    }
}
