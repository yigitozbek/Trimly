import Foundation

/// How a folder is handled in a nested plan: moved as one unit, or its contents distributed individually.
public enum FolderMode: String, Codable, Sendable {
    case keep
    case distribute
}
