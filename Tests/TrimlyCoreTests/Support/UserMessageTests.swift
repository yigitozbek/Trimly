import Foundation
import Testing
@testable import TrimlyCore

struct UserMessageTests {
    @Test(arguments: [
        (DataLockError.busy as any Error, "Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin."),
        (PlanError.alreadyApplied as any Error, "Bu plan zaten uygulanmış; yeni bir plan oluşturun."),
        (ExecutionError.notReady as any Error, "Plan henüz tamamlanmamış; önce taramayı bitirin."),
        (LLMError.unreachable as any Error, "Ollama erişilemiyor."),
        (LLMError.http(500) as any Error, "Ollama hata döndürdü (HTTP 500)."),
        (LLMError.malformedResponse as any Error, "Model geçersiz yanıt verdi."),
        (UndoError.runNotFound("r-yok") as any Error, "İşlem bulunamadı: r-yok")
    ])
    func messages(error: any Error, text: String) {
        #expect(UserMessage.text(for: error) == text)
    }

    @Test func readiness() {
        #expect(LLMReadiness.problem(ProviderHealth(reachable: false, availableModels: []), model: "qwen3:4b") == "Ollama erişilemiyor")
        #expect(LLMReadiness.problem(ProviderHealth(reachable: true, availableModels: ["llama3.1:latest"]), model: "qwen3:4b") == "qwen3:4b yüklü değil")
        #expect(LLMReadiness.problem(ProviderHealth(reachable: true, availableModels: ["llama3.1:latest"]), model: "llama3.1") == nil)
        #expect(LLMReadiness.problem(ProviderHealth(reachable: true, availableModels: ["qwen3:4b"]), model: "qwen3:4b") == nil)
    }
}
