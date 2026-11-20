import Foundation

public enum ItemStatus: String, Codable, Sendable {
    case ready
    case review
    case skipped
    case critical
}
