import Foundation

public struct SourceFingerprint: Codable, Equatable, Sendable {
    public let size: Int64?
    public let modifiedAt: Date

    public init(size: Int64?, modifiedAt: Date) {
        self.size = size
        self.modifiedAt = modifiedAt
    }
}
