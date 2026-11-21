import TrimlyCore

/// Provider whose Ollama can be "started" mid-test.
actor SwitchableProvider: LLMProvider {
    private let wrapped: any LLMProvider
    private var reachable: Bool

    init(wrapping wrapped: any LLMProvider, reachable: Bool) {
        self.wrapped = wrapped
        self.reachable = reachable
    }

    func setReachable(_ value: Bool) {
        reachable = value
    }

    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        guard reachable else { throw LLMError.unreachable }
        return try await wrapped.classify(request, model: model)
    }

    func unload(model: String) async {}

    func health() async -> ProviderHealth {
        ProviderHealth(reachable: reachable, availableModels: reachable ? ["qwen3:4b", "ministral-3:14b"] : [])
    }
}
