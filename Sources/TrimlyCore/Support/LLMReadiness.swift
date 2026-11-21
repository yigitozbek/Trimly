import Foundation

public enum LLMReadiness {
    /// Why the LLM cannot be used for `model`, or `nil` when Ollama answers and the model is installed.
    public static func problem(_ health: ProviderHealth, model: String) -> String? {
        guard health.reachable else {
            return "Ollama erişilemiyor"
        }
        guard health.availableModels.contains(model) || health.availableModels.contains(model + ":latest") else {
            return "\(model) yüklü değil"
        }
        return nil
    }
}
