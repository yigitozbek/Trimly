import TrimlyCore

/// Healthy provider whose `health()` waits on a gate, to hold a session inside its start-up health check.
struct SlowHealthProvider: LLMProvider {
    let gate: Gate

    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        throw LLMError.unreachable
    }

    func unload(model: String) async {}

    func health() async -> ProviderHealth {
        await gate.enterAndWait()
        return ProviderHealth(reachable: true, availableModels: ["qwen3:4b", "ministral-3:14b"])
    }
}
