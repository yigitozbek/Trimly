import Foundation
import TrimlyCore

/// Scripted LLM: answers by file name, records requests/unloads, and can simulate cancellation after N calls.
actor MockLLMProvider: LLMProvider {
    private let results: [String: Result<ClassificationResult, any Error>]
    private let defaultResult: Result<ClassificationResult, any Error>?
    private let cancelAfterCalls: Int?
    private(set) var requests: [(request: ClassificationRequest, model: String)] = []
    private(set) var unloaded: [String] = []
    private(set) var events: [String] = []

    init(
        results: [String: Result<ClassificationResult, any Error>] = [:],
        defaultResult: Result<ClassificationResult, any Error>? = nil,
        cancelAfterCalls: Int? = nil
    ) {
        self.results = results
        self.defaultResult = defaultResult
        self.cancelAfterCalls = cancelAfterCalls
    }

    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        if let cancelAfterCalls, requests.count >= cancelAfterCalls {
            throw CancellationError()
        }
        requests.append((request, model))
        events.append("classify:\(model):\(request.name)")
        guard let result = results[request.name] ?? defaultResult else {
            throw LLMError.malformedResponse
        }
        return try result.get()
    }

    func unload(model: String) async {
        unloaded.append(model)
        events.append("unload:\(model)")
    }

    func health() async -> ProviderHealth {
        ProviderHealth(reachable: true, availableModels: [])
    }
}
