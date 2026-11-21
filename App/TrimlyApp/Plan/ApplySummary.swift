import TrimlyCore

/// What the apply confirmation sheet shows.
struct ApplySummary: Equatable {
    let count: Int
    let byCategory: [CategoryCount]
    let criticalApproved: [PlanItem]
}
