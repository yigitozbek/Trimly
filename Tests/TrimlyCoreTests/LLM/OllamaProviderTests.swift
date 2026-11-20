import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.networking))
struct OllamaProviderTests {
    let allowed = ["Belgeler", "Faturalar", "Diger"]
    let validContent = #"{"target_folder":"Faturalar","suggested_name":"Enerjisa Ocak","confidence":0.91,"reason":"Fatura no"}"#

    var request: ClassificationRequest {
        ClassificationRequest(
            name: "download (3).pdf", fileExtension: "pdf", kind: .file, sizeBytes: 1, createdAt: nil, modifiedAt: nil,
            utType: nil, sourceHost: nil, spotlightTitle: nil, spotlightAuthors: [], ruleHintCategoryFolder: "Belgeler",
            folderSampleNames: [], contentPreview: nil, allowedFolders: allowed
        )
    }

    func provider(_ transport: some HTTPTransport) -> OllamaProvider {
        OllamaProvider(baseURL: URL(string: "http://localhost:11434")!, timeout: 60, keepAlive: "2m", transport: transport)
    }

    func reply(_ content: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["message": ["content": content]])
    }

    @Test func chatRequestBodyMatchesContract() async throws {
        let transport = RecordingTransport(responses: [.success((200, reply(validContent)))])
        _ = try await provider(transport).classify(request, model: "qwen3:4b")
        let sent = try #require(await transport.requests.first)
        #expect(sent.url?.path == "/api/chat" && sent.httpMethod == "POST")
        let body = try RecordingTransport.bodyJSON(sent)
        #expect(body["model"] as? String == "qwen3:4b" && body["stream"] as? Bool == false && body["think"] as? Bool == false)
        #expect(body["keep_alive"] as? String == "2m")
        let options = try #require(body["options"] as? [String: Any])
        #expect(options["temperature"] as? Double == 0 && options["num_ctx"] as? Int == 4096)
        let format = try #require(body["format"] as? [String: Any])
        #expect(format["required"] as? [String] == ["target_folder", "suggested_name", "confidence", "reason"])
        #expect(format["additionalProperties"] as? Bool == false)
        let properties = try #require(format["properties"] as? [String: Any])
        #expect((properties["target_folder"] as? [String: Any])?["enum"] as? [String] == allowed)
        #expect((body["messages"] as? [[String: Any]])?.compactMap { $0["role"] as? String } == ["system", "user"])
    }

    @Test func decodesResult() async throws {
        let transport = RecordingTransport(responses: [.success((200, reply(validContent)))])
        let result = try await provider(transport).classify(request, model: "qwen3:4b")
        #expect(result == ClassificationResult(targetFolder: "Faturalar", suggestedName: "Enerjisa Ocak", confidence: 0.91, reason: "Fatura no"))
    }

    @Test func rejectsFolderOutsideEnum() async {
        let content = #"{"target_folder":"Uydurma","suggested_name":"x","confidence":0.9,"reason":"r"}"#
        let transport = RecordingTransport(responses: [.success((200, reply(content)))])
        await #expect(throws: LLMError.folderNotAllowed("Uydurma")) {
            try await provider(transport).classify(request, model: "qwen3:4b")
        }
    }

    @Test func rejectsConfidenceOutOfRange() async {
        let content = #"{"target_folder":"Faturalar","suggested_name":"x","confidence":1.4,"reason":"r"}"#
        let transport = RecordingTransport(responses: [.success((200, reply(content)))])
        await #expect(throws: LLMError.confidenceOutOfRange(1.4)) {
            try await provider(transport).classify(request, model: "qwen3:4b")
        }
    }

    @Test func retriesOnceThenThrows() async {
        let transport = RecordingTransport(responses: [.success((500, Data())), .success((500, Data()))])
        await #expect(throws: LLMError.http(500)) {
            try await provider(transport).classify(request, model: "qwen3:4b")
        }
        #expect(await transport.requests.count == 2)
    }

    @Test func succeedsOnRetry() async throws {
        let transport = RecordingTransport(responses: [.success((500, Data())), .success((200, reply(validContent)))])
        let result = try await provider(transport).classify(request, model: "qwen3:4b")
        #expect(result.targetFolder == "Faturalar")
        #expect(await transport.requests.count == 2)
    }

    @Test func cancellationIsNotRetried() async {
        let transport = RecordingTransport(responses: [.failure(CancellationError())])
        await #expect(throws: CancellationError.self) {
            try await provider(transport).classify(request, model: "qwen3:4b")
        }
        #expect(await transport.requests.count == 1)
    }

    @Test func unloadSendsKeepAliveZero() async throws {
        let transport = RecordingTransport(responses: [.success((200, Data("{}".utf8)))])
        await provider(transport).unload(model: "qwen3:4b")
        let sent = try #require(await transport.requests.first)
        #expect(sent.url?.path == "/api/generate")
        let body = try RecordingTransport.bodyJSON(sent)
        #expect(body["model"] as? String == "qwen3:4b" && body["keep_alive"] as? Int == 0)
    }

    @Test func healthListsModels() async {
        let tags = Data(#"{"models":[{"name":"qwen3:4b"}]}"#.utf8)
        let health = await provider(RecordingTransport(responses: [.success((200, tags))])).health()
        #expect(health == ProviderHealth(reachable: true, availableModels: ["qwen3:4b"]))
        let down = await provider(RecordingTransport(responses: [.failure(LLMError.unreachable)])).health()
        #expect(down.reachable == false)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["TRIMLY_OLLAMA_TESTS"] == "1"), .timeLimit(.minutes(1)))
    func liveOllamaReturnsSchemaValidResult() async throws {
        let live = OllamaProvider(baseURL: URL(string: "http://localhost:11434")!, timeout: 60, keepAlive: "2m")
        var req = request
        req.name = "Enerjisa_fatura_ocak.pdf"
        let result = try await live.classify(req, model: "qwen3:4b")
        #expect(allowed.contains(result.targetFolder))
        #expect((0...1).contains(result.confidence))
    }
}
