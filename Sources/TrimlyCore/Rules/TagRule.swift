import Foundation

/// Finder tags are the user's own labels, so they decide the category before any name pattern.
public enum TagRule {
    /// Tries the tags in Finder's order; the first one that maps wins. A tag maps through `tagMappings`
    /// (unknown category ids are ignored), else when it names a category's folder or tag in any language.
    /// Comparison ignores case, accents, spaces and punctuation (`Resmi Evrak` = `Resmi-Evrak`).
    public static func match(_ tags: [String], settings: Settings) -> (categoryID: String, tag: String)? {
        let mappings = Dictionary(settings.tagMappings.map { (key($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        for tag in tags {
            let tagKey = key(tag)
            if let id = mappings[tagKey], settings.category(id: id) != nil {
                return (id, tag)
            }
            let named = settings.categories.first { category in
                (category.folder.allValues + category.tag.allValues).contains { key($0) == tagKey }
            }
            if let named {
                return (named.id, tag)
            }
        }
        return nil
    }

    private static func key(_ text: String) -> String {
        let latin = Normalizer.ascii(text).lowercased().filter { $0.isLetter || $0.isNumber }
        // CJK / Hangul category names are not ASCII; keep their letters when folding would empty the key.
        if latin.isEmpty == false {
            return latin
        }
        return text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
