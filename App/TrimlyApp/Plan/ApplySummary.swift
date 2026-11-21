import TrimlyCore

/// What the apply confirmation sheet shows.
struct ApplySummary: Equatable {
    let count: Int
    let byCategory: [CategoryCount]
    let criticalApproved: [PlanItem]
    /// Exactly the items shown; apply refuses if the plan's approvals differ by then.
    let itemIDs: Set<String>
    /// The plan's settings remove folders the run empties (recreated on undo).
    var removesEmptyFolders = false
}
