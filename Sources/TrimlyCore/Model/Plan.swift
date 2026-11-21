import Foundation

public struct Plan: Codable, Equatable, Sendable {
    /// Bumped whenever classification or safety rules change, so plans made by an older engine are never reused.
    /// History: 1 = phase 1 (no field in JSON), 2 = phase 2 final-review rules.
    public static let currentEngineVersion = 2

    public let id: String
    public let root: URL
    public let createdAt: Date
    public var state: PlanState
    public var appliedRunID: String?
    public var settingsSnapshot: Settings
    public var items: [PlanItem]
    /// `nil` for plans written before the field existed.
    public var engineVersion: Int?

    public init(
        id: String,
        root: URL,
        createdAt: Date,
        state: PlanState,
        appliedRunID: String? = nil,
        settingsSnapshot: Settings,
        items: [PlanItem],
        engineVersion: Int? = Plan.currentEngineVersion
    ) {
        self.id = id
        self.root = root
        self.createdAt = createdAt
        self.state = state
        self.appliedRunID = appliedRunID
        self.settingsSnapshot = settingsSnapshot
        self.items = items
        self.engineVersion = engineVersion
    }

    /// A saved plan may be resumed or reopened only if the current engine made it with exactly the current settings;
    /// otherwise its classifications (and critical-item decisions) could be stale.
    public func isReusable(with settings: Settings) -> Bool {
        engineVersion == Self.currentEngineVersion && settingsSnapshot == settings
    }
}
