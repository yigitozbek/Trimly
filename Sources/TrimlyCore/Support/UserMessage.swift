import Foundation

/// Turkish, user-facing text for every error the core can throw. Shared by the CLI and the app.
public enum UserMessage {
    public static func text(for error: any Error) -> String {
        switch error {
        case PlanError.notFound(let id): "Plan bulunamadı: \(id)"
        case PlanError.itemNotFound(let id): "Öğe bulunamadı: \(id)"
        case PlanError.unknownCategory(let id): "Bilinmeyen kategori: \(id). Geçerli kimlikler: \(Settings().categories.map(\.id).joined(separator: ", "))"
        case PlanError.alreadyApplied, ExecutionError.alreadyApplied: "Bu plan zaten uygulanmış; yeni bir plan oluşturun."
        case PlanError.notReady, ExecutionError.notReady: "Plan henüz tamamlanmamış; önce taramayı bitirin."
        case UndoError.noRuns: "Geri alınacak işlem yok."
        case UndoError.runNotFound(let id): "İşlem bulunamadı: \(id)"
        case ScanError.notADirectory(let url): "Klasör değil: \(url.path)"
        case DataLockError.busy: "Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin."
        case LLMError.unreachable: "Ollama erişilemiyor."
        case LLMError.http(let code): "Ollama hata döndürdü (HTTP \(code))."
        case LLMError.malformedResponse, LLMError.folderNotAllowed, LLMError.confidenceOutOfRange: "Model geçersiz yanıt verdi."
        default: error.localizedDescription
        }
    }
}
