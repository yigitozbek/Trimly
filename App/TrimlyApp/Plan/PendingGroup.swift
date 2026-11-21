import TrimlyCore

/// Pending rows of the plan window: the top level, or the rows inside one mixed (distributed) folder,
/// whose own row is the group's heading (it never moves itself).
struct PendingGroup: Identifiable {
    static let topLevelID = "root"

    let id: String
    let folder: PlanItem?
    let title: String
    let items: [PlanItem]
}
