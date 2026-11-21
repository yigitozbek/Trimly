import Foundation

/// Derives which items travel inside a kept folder (`covered`) from the folder modes along each item's
/// parent chain. Covered items are never approved or targeted; distributed folders never move themselves.
public enum CoverageResolver {
    public static func apply(_ plan: inout Plan) {
        var coveredByID: [String: Bool] = [:]
        var keepByID: [String: Bool] = [:]
        for index in plan.items.indices.sorted(by: { plan.items[$0].depth < plan.items[$1].depth }) {
            let item = plan.items[index]
            let covered = item.parentID.map { (coveredByID[$0] ?? false) || (keepByID[$0] ?? false) } ?? false
            coveredByID[item.id] = covered
            keepByID[item.id] = item.kind == .folder && item.folderMode == .keep
            plan.items[index].covered = covered
            if covered || (item.kind == .folder && item.folderMode == .distribute) {
                plan.items[index].approved = false
                plan.items[index].target = nil
            }
        }
    }
}
