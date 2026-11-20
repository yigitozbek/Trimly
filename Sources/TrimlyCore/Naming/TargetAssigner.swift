import Foundation

/// (Re)computes every item's target from the plan's settings snapshot. Items are processed by name so the
/// `_2`, `_3` suffixes are deterministic across runs and edits.
public enum TargetAssigner {
    public static func assign(_ plan: inout Plan) {
        let settings = plan.settingsSnapshot
        let language = settings.categoryLanguage
        var resolver = TargetResolver(root: plan.root, settings: settings)
        let order = plan.items.indices.sorted { plan.items[$0].name < plan.items[$1].name }

        for index in order {
            var item = plan.items[index]
            guard item.status != .skipped,
                  let categoryID = item.categoryID,
                  let category = settings.category(id: categoryID) else {
                item.target = nil
                plan.items[index] = item
                continue
            }
            let folder = resolver.folderURL(categoryFolder: category.folder.value(language), date: item.resolvedDate)
            let fileName = if item.kind == .folder {
                NamingTemplate.folderName(preset: settings.namingPreset, originalName: item.name)
            } else {
                NamingTemplate.fileName(
                    preset: settings.namingPreset,
                    day: DateResolver.dayString(item.resolvedDate),
                    categoryTag: category.tag.value(language),
                    description: item.description ?? (language == .tr ? "Dosya" : "File"),
                    originalName: item.name,
                    fileExtension: item.fileExtension
                )
            }
            let target = resolver.reserve(fileName: fileName, in: folder, source: item.source)
            if TargetResolver.samePath(target, item.source) {
                item.status = .skipped
                item.skipReason = "Zaten düzenli"
                item.approved = false
                item.target = nil
            } else {
                item.target = target
            }
            plan.items[index] = item
        }
    }
}
