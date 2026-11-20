import Foundation

public enum DecidedBy: String, Codable, Sendable {
    case rule
    case llm1
    case llm2
    case manual
}
