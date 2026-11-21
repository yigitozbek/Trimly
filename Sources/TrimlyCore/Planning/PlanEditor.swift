import Foundation

/// Manual decisions on a ready plan. The only way a critical item becomes approved is an explicit
/// per-item `set(... approve: true)`; bulk approval never includes critical items.
public enum PlanEditor {
    public static func set(_ plan: inout Plan, itemID: String, categoryID: String?, description: String?, approve: Bool?) throws {
        switch plan.state {
        case .applied: throw PlanError.alreadyApplied
        case .inProgress: throw PlanError.notReady
        case .ready: break
        }
        guard let index = plan.items.firstIndex(where: { $0.id == itemID }) else {
            throw PlanError.itemNotFound(itemID)
        }
        let settings = plan.settingsSnapshot
        if let categoryID, settings.category(id: categoryID) == nil {
            throw PlanError.unknownCategory(categoryID)
        }

        var item = plan.items[index]
        if categoryID != nil || description != nil {
            if let categoryID {
                item.categoryID = categoryID
            }
            guard let category = item.categoryID.flatMap(settings.category(id:)) else {
                throw PlanError.unknownCategory(item.categoryID ?? "")
            }
            item.description = Planner.describe(item, llm: description ?? item.description, hint: nil, category: category, settings: settings)
            item.decidedBy = .manual
            item.classified = true
            item.skipReason = nil
            item.reviewReason = nil
            item.status = item.critical ? .critical : .ready
        }
        if let approve {
            item.approved = approve
        }
        plan.items[index] = item
        TargetAssigner.assign(&plan)
    }

    /// Approves matching items and returns how many changed. Filters combine with AND.
    /// Never includes critical, skipped or target-less items; folders only with `includeFolders`.
    public static func bulkApprove(_ plan: inout Plan, categoryID: String?, reviewReason: ReviewReason?, minConfidence: Double?, includeFolders: Bool) -> Int {
        guard plan.state == .ready else {
            return 0
        }
        var changed = 0
        for index in plan.items.indices {
            let item = plan.items[index]
            guard item.approved == false,
                  item.critical == false,
                  item.status != .critical,
                  item.status != .skipped,
                  item.target != nil,
                  item.kind != .folder || includeFolders,
                  categoryID == nil || item.categoryID == categoryID,
                  reviewReason == nil || item.reviewReason == reviewReason,
                  minConfidence.map({ (item.confidence ?? 0) >= $0 }) ?? true else {
                continue
            }
            plan.items[index].approved = true
            changed += 1
        }
        return changed
    }

    /// Un-approves matching items (all non-skipped items when `categoryID` is nil) and returns how many changed.
    /// Rejecting is always safe, so critical items are included.
    public static func bulkReject(_ plan: inout Plan, categoryID: String?) -> Int {
        guard plan.state == .ready else {
            return 0
        }
        var changed = 0
        for index in plan.items.indices {
            let item = plan.items[index]
            guard item.approved, item.status != .skipped, categoryID == nil || item.categoryID == categoryID else {
                continue
            }
            plan.items[index].approved = false
            changed += 1
        }
        return changed
    }
}
