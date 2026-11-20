import Foundation

public enum ReviewReason: String, Codable, Sendable, CaseIterable {
    case lowConfidence
    case llmError
    case weakRuleNoLLM
    case folder
}
