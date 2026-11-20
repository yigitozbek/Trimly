import Foundation

public enum EntryKind: String, Codable, Sendable {
    case file
    case folder
    case package
}
