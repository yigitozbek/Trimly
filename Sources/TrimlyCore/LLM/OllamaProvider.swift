import Foundation

/// Ollama HTTP client: `/api/chat` with a JSON-schema `format`, one retry, cancellation never retried.
public struct OllamaProvider: LLMProvider {
    private let baseURL: URL
    private let timeout: TimeInterval
    private let keepAlive: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, timeout: TimeInterval, keepAlive: String, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.keepAlive = keepAlive
        self.transport = transport
    }

    public func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        var lastError: any Error = LLMError.unreachable
        for _ in 0..<2 {
            try Task.checkCancellation()
            do {
                return try await classifyOnce(request, model: model)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    public func unload(model: String) async {
        let body: [String: Any] = ["model": model, "keep_alive": 0]
        _ = try? await post("api/generate", body: body)
    }

    public func health() async -> ProviderHealth {
        struct Tags: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        var request = URLRequest(url: baseURL.appending(path: "api/tags"))
        request.timeoutInterval = 5
        guard let (data, response) = try? await transport.send(request),
              response.statusCode == 200,
              let tags = try? JSONDecoder().decode(Tags.self, from: data) else {
            return ProviderHealth(reachable: false, availableModels: [])
        }
        return ProviderHealth(reachable: true, availableModels: tags.models.map(\.name))
    }

    private func classifyOnce(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult {
        struct ChatResponse: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": PromptBuilder.systemPrompt],
                ["role": "user", "content": PromptBuilder.userMessage(request)]
            ],
            "stream": false,
            "think": false,
            "format": ResponseSchema.json(allowedFolders: request.allowedFolders),
            "options": ["temperature": 0.0, "num_ctx": 4096],
            "keep_alive": keepAlive
        ]
        let data = try await post("api/chat", body: body)
        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let result = try? JSONDecoder().decode(ClassificationResult.self, from: Data(chat.message.content.utf8)) else {
            throw LLMError.malformedResponse
        }
        guard request.allowedFolders.contains(result.targetFolder) else {
            throw LLMError.folderNotAllowed(result.targetFolder)
        }
        guard (0...1).contains(result.confidence) else {
            throw LLMError.confidenceOutOfRange(result.confidence)
        }
        return result
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200 else {
            throw LLMError.http(response.statusCode)
        }
        return data
    }
}
