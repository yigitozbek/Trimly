import Foundation

/// Reads and writes Finder tags via the `tagNames` resource key.
/// Writing goes through `NSURL` because `URLResourceValues.tagNames` is settable only on macOS 26+.
public enum FinderTags {
    /// Successful `nil`/`[]` means the file has no tags. A permission or I/O error throws — never pretend the
    /// file is untagged, or a later write would replace real tags with only the category tag.
    public static func read(_ url: URL) throws -> [String] {
        (url as NSURL).removeCachedResourceValue(forKey: .tagNamesKey)
        let path = url.path
        let key = "com.apple.metadata:_kMDItemUserTags"
        errno = 0
        let size = getxattr(path, key, nil, 0, 0, 0)
        if size < 0 {
            // No attribute → no tags. Anything else (EACCES, ENOENT, …) must not look like an empty list.
            if errno == ENOATTR {
                return []
            }
            throw FinderTagsError.unreadable(url)
        }
        let values = try url.resourceValues(forKeys: [.tagNamesKey])
        return values.tagNames ?? []
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

public enum FinderTagsError: Error, LocalizedError, Sendable {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url): "Etiketler okunamadı (\(url.lastPathComponent))"
        }
    }
}
