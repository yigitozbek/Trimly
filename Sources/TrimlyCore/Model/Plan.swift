import Foundation

public struct Plan: Codable, Equatable, Sendable {
    /// Bumped whenever classification or safety rules change, so plans made by an older engine are never reused.
    /// History: 1 = phase 1 (no field in JSON), 2 = phase 2 final-review rules, 3 = nested scanning.
    public static let currentEngineVersion = 3

    public let id: String
    public let root: URL
    public let createdAt: Date
    public var state: PlanState
    public var appliedRunID: String?
    public var settingsSnapshot: Settings
    public var items: [PlanItem]
    /// `nil` for plans written before the field existed.
    public var engineVersion: Int?
    /// The scan hit the item limit and did not descend further.
    public var truncated: Bool

    public init(
        id: String,
        root: URL,
        createdAt: Date,
        state: PlanState,
        appliedRunID: String? = nil,
        settingsSnapshot: Settings,
        items: [PlanItem],
        engineVersion: Int? = Plan.currentEngineVersion,
        truncated: Bool = false
    ) {
        self.id = id
        self.root = root
        self.createdAt = createdAt
        self.state = state
        self.appliedRunID = appliedRunID
        self.settingsSnapshot = settingsSnapshot
        self.items = items
        self.engineVersion = engineVersion
        self.truncated = truncated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        root = try c.decode(URL.self, forKey: .root)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        state = try c.decode(PlanState.self, forKey: .state)
        appliedRunID = try c.decodeIfPresent(String.self, forKey: .appliedRunID)
        settingsSnapshot = try c.decode(Settings.self, forKey: .settingsSnapshot)
        items = try c.decode([PlanItem].self, forKey: .items)
        engineVersion = try c.decodeIfPresent(Int.self, forKey: .engineVersion)
        truncated = try c.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
    }

    /// A saved plan may be resumed or reopened only if the current engine made it with exactly the current settings;
    /// otherwise its classifications (and critical-item decisions) could be stale.
    public func isReusable(with settings: Settings) -> Bool {
        engineVersion == Self.currentEngineVersion && settingsSnapshot == settings
    }
}
