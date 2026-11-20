import CoreServices
import Foundation

public enum MetadataReader {
    /// Spotlight attributes for `url`; empty values when the item is not indexed.
    public static func spotlight(for url: URL) -> SpotlightInfo {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else {
            return SpotlightInfo()
        }
        func value<T>(_ key: CFString) -> T? {
            MDItemCopyAttribute(item, key) as? T
        }
        return SpotlightInfo(
            dateAdded: value(kMDItemDateAdded),
            whereFroms: value(kMDItemWhereFroms) ?? [],
            title: value(kMDItemTitle),
            authors: value(kMDItemAuthors) ?? [],
            contentCreationDate: value(kMDItemContentCreationDate)
        )
    }
}
