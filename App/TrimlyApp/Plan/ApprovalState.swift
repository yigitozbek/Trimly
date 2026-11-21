import TrimlyCore

enum ApprovalState: Equatable {
    case all
    case none
    case mixed

    static func of(_ items: [PlanItem]) -> ApprovalState {
        let approved = items.filter(\.approved).count
        if approved == 0 {
            return .none
        }
        return approved == items.count ? .all : .mixed
    }
}
