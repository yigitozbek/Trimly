import Foundation

/// Reads and writes Finder tags via the `tagNames` resource key.
/// Writing goes through `NSURL` because `URLResourceValues.tagNames` is settable only on macOS 26+.
public enum FinderTags {
    public static func read(_ url: URL) -> [String] {
        (url as NSURL).removeCachedResourceValue(forKey: .tagNamesKey)
        return (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    public static func write(_ tags: [String], to url: URL) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
        (url as NSURL).removeCachedResourceValue(forKey: .tagNamesKey)
    }

    /// Case- and diacritic-insensitive membership used when deciding whether a tag is already present.
    public static func contains(_ tag: String, in tags: [String]) -> Bool {
        tags.contains { $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    /// Exact set equality for journal recovery / "tags changed since" checks.
    public static func sameSet(_ lhs: [String], _ rhs: [String]) -> Bool {
        Set(lhs) == Set(rhs)
    }
}
