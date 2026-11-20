import Foundation

public struct PatternCount: Codable, Equatable, Sendable {
    public let pattern: String
    public let count: Int

    public init(pattern: String, count: Int) {
        self.pattern = pattern
        self.count = count
    }
}
