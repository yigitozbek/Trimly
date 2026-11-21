import Foundation

public enum JournalOp: String, Codable, Sendable {
    case mkdir
    case move
    case undo
    case rmdir
}
