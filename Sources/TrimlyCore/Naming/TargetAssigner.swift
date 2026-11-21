import Foundation

/// (Re)computes every item's target and the tags a run adds, from the plan's settings snapshot. Items are processed
/// by path so the `_2`, `_3` suffixes are deterministic across runs and edits. In `tagOnly` mode nothing gets a target.
public enum TargetAssigner {
    public static func assign(_ plan: inout Plan) {
        let settings = plan.settingsSnapshot
        let language = settings.categoryLanguage
        var resolver = TargetResolver(root: plan.root, settings: settings)
        let order = plan.items.indices.sorted { plan.items[$0].relativePath < plan.items[$1].relativePath }

        for index in order {
            var item = plan.items[index]
            item.tagsToAdd = []
            // Covered items move with their kept folder; a distributed folder never moves itself.
            guard item.status != .skipped,
                  item.covered == false,
                  item.kind != .folder || item.folderMode != .distribute,
                  let categoryID = item.categoryID,
                  let category = settings.category(id: categoryID) else {
                item.target = nil
                plan.items[index] = item
                continue
            }
            let tag = category.tag.value(language)
            let hasTag = item.existingTags.contains { $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            if settings.targetMode == .tagOnly {
                item.target = nil
                if hasTag {
                    item.status = .skipped
                    item.skipReason = "Zaten etiketli"
                    item.approved = false
                } else {
                    item.tagsToAdd = [tag]
                }
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
                item.tagsToAdd = settings.addCategoryTags && hasTag == false ? [tag] : []
            }
            plan.items[index] = item
        }
    }
}
