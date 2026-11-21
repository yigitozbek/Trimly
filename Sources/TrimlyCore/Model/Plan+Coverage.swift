import Foundation

extension Plan {
    /// IDs of kept folders that carry a critical item inside them. Bulk approval treats them like critical items:
    /// only an explicit, single-item decision may approve them.
    public func foldersCarryingCritical() -> Set<String> {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var carrying: Set<String> = []
        for item in items where item.covered && (item.critical || item.status == .critical) {
            var parent = item.parentID.flatMap { byID[$0] }
            while let folder = parent {
                if folder.folderMode == .keep && folder.covered == false {
                    carrying.insert(folder.id)
                    break
                }
                parent = folder.parentID.flatMap { byID[$0] }
            }
        }
        return carrying
    }
}
