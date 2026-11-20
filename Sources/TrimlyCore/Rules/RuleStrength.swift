import Foundation

public enum RuleStrength: String, Codable, Sendable {
    /// Category is certain; the LLM is not called.
    case decisive
    /// Category is a guess; the LLM decides when available, otherwise the item goes to review.
    case weak
}
