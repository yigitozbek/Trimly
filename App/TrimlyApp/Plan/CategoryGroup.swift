import TrimlyCore

/// Ready items of one category, shown collapsed under a header with a tri-state checkbox.
struct CategoryGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [PlanItem]
    let approval: ApprovalState
}
