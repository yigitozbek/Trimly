import Foundation

/// Recognises items that already carry Trimly's name inside a Trimly category folder, so a rerun leaves them
/// in place (or, in central mode, migrates them unchanged) instead of asking the rules or the LLM for a new name.
public enum OrganizedName {
    public struct Match: Sendable, Equatable {
        public let categoryID: String
        /// The description part of the name; `nil` for folders and presets without one.
        public let description: String?

        public init(categoryID: String, description: String?) {
            self.categoryID = categoryID
            self.description = description
        }
    }

    public static func match(_ item: FileItem, settings: Settings) -> Match? {
        guard item.depth > 0,
              let top = item.relativePath.split(separator: "/").first.map(String.init),
              let category = settings.category(forFolderName: top) else {
            return nil
        }
        if item.kind == .folder {
            let normalized = NamingTemplate.folderName(preset: settings.namingPreset, originalName: item.name)
            return normalized == item.name ? Match(categoryID: category.id, description: nil) : nil
        }
        let ext = item.fileExtension
        let stem = ext.isEmpty ? Substring(item.name) : item.name.dropLast(ext.count + 1)
        let description: Substring?
        switch settings.namingPreset {
        case .dateCategoryDescription:
            description = withoutDay(stem).flatMap { descriptionAfterAnyTag($0, category: category) }
        case .categoryDescription:
            description = descriptionAfterAnyTag(stem, category: category)
        case .dateDescription:
            description = withoutDay(stem)
        case .originalNormalized:
            return Normalizer.normalizedFileName(item.name, isFolder: false) == item.name ? Match(categoryID: category.id, description: nil) : nil
        case .keepOriginal:
            return Match(categoryID: category.id, description: nil)
        }
        guard let description, description.isEmpty == false else {
            return nil
        }
        return Match(categoryID: category.id, description: String(description))
    }

    /// Accepts a tag prefix written in any category language (e.g. after the user switches language).
    private static func descriptionAfterAnyTag(_ stem: Substring, category: Category) -> Substring? {
        for tag in category.tag.allValues {
            let prefix = tag + "_"
            if stem.hasPrefix(prefix) {
                return stem.dropFirst(prefix.count)
            }
        }
        return nil
    }

    /// Drops a leading `YYYY-MM-DD_`.
    private static func withoutDay(_ stem: Substring) -> Substring? {
        guard stem.prefix(10).wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil, stem.dropFirst(10).first == "_" else {
            return nil
        }
        return stem.dropFirst(11)
    }
}
