import Testing
import TrimlyCore
@testable import TrimlyApp

struct OllamaStatusTests {
    @Test func mapsHealth() {
        #expect(OllamaStatus.from(ProviderHealth(reachable: false, availableModels: []), model: "qwen3:4b") == .unreachable)
        #expect(OllamaStatus.from(ProviderHealth(reachable: true, availableModels: []), model: "qwen3:4b") == .modelMissing("qwen3:4b"))
        #expect(OllamaStatus.from(ProviderHealth(reachable: true, availableModels: ["qwen3:4b"]), model: "qwen3:4b") == .ready)
    }

    @Test func labels() {
        #expect(OllamaStatus.ready.label == "Hazır")
        #expect(OllamaStatus.modelMissing("qwen3:4b").label == "qwen3:4b yüklü değil")
        #expect(OllamaStatus.unreachable.label == "Ollama erişilemiyor")
    }
}
