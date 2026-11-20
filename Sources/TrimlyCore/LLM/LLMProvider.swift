import Foundation

/// Local model behind an abstraction, so the pipeline never depends on a concrete runtime.
public protocol LLMProvider: Sendable {
    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult
    func unload(model: String) async
    func health() async -> ProviderHealth
}
