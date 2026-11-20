import Foundation

public struct RuleMatch: Equatable, Sendable {
    public let categoryID: String
    public let strength: RuleStrength
    public let descriptionHint: String?

    public init(categoryID: String, strength: RuleStrength, descriptionHint: String?) {
        self.categoryID = categoryID
        self.strength = strength
        self.descriptionHint = descriptionHint
    }
}
