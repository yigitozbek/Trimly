import Foundation

public struct ClassificationResult: Codable, Equatable, Sendable {
    public let targetFolder: String
    /// Short description only; the naming template adds date, category and extension.
    public let suggestedName: String
    public let confidence: Double
    public let reason: String

    public init(targetFolder: String, suggestedName: String, confidence: Double, reason: String) {
        self.targetFolder = targetFolder
        self.suggestedName = suggestedName
        self.confidence = confidence
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case targetFolder = "target_folder"
        case suggestedName = "suggested_name"
        case confidence
        case reason
    }
}
