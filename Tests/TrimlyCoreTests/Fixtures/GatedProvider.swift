import TrimlyCore

/// Healthy provider whose first `classify` waits on a `Gate`; later calls pass once the gate is released.
/// Checks cancellation after the gate so tests can verify that cancelling really stops the work.
struct GatedProvider: LLMProvider {
    let gate: Gate
    let wrapped: any LLMProvider

    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        await gate.enterAndWait()
        try Task.checkCancellation()
        return try await wrapped.classify(request, model: model)
    }

    func unload(model: String) async {
        await wrapped.unload(model: model)
    }

    func health() async -> ProviderHealth {
        ProviderHealth(reachable: true, availableModels: ["qwen3:4b", "ministral-3:14b"])
    }
}
