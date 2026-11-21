import TrimlyCore

enum OllamaStatus: Equatable {
    case unknown
    case ready
    case modelMissing(String)
    case unreachable

    static func from(_ health: ProviderHealth, model: String) -> OllamaStatus {
        guard health.reachable else {
            return .unreachable
        }
        return LLMReadiness.problem(health, model: model) == nil ? .ready : .modelMissing(model)
    }

    var label: String {
        switch self {
        case .unknown: "Kontrol ediliyor…"
        case .ready: "Hazır"
        case .modelMissing(let model): "\(model) yüklü değil"
        case .unreachable: "Ollama erişilemiyor"
        }
    }
}
