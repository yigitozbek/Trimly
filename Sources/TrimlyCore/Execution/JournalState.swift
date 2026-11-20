import Foundation

public enum JournalState: String, Codable, Sendable {
    case pending
    case done
    case failed
    case skipped
}
