import Foundation

public struct RuleMatch: Equatable, Sendable {
    public let categoryID: String
    public let strength: RuleStrength
    public let descriptionHint: String?
    /// The Finder tag that decided the category, if any.
    public let tag: String?

    public init(categoryID: String, strength: RuleStrength, descriptionHint: String?, tag: String? = nil) {
        self.categoryID = categoryID
        self.strength = strength
        self.descriptionHint = descriptionHint
        self.tag = tag
    }
}
