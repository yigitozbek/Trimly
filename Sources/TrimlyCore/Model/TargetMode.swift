import Foundation

public enum TargetMode: String, Codable, Sendable {
    case inPlace
    case central
    /// Nothing moves; approved items only get their category tag.
    case tagOnly
}
