import Foundation

public struct Plan: Codable, Equatable, Sendable {
    public let id: String
    public let root: URL
    public let createdAt: Date
    public var state: PlanState
    public var appliedRunID: String?
    public var settingsSnapshot: Settings
    public var items: [PlanItem]

    public init(
        id: String,
        root: URL,
        createdAt: Date,
        state: PlanState,
        appliedRunID: String? = nil,
        settingsSnapshot: Settings,
        items: [PlanItem]
    ) {
        self.id = id
        self.root = root
        self.createdAt = createdAt
        self.state = state
        self.appliedRunID = appliedRunID
        self.settingsSnapshot = settingsSnapshot
        self.items = items
    }
}
