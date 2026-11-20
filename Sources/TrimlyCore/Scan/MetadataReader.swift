import CoreServices
import Foundation

public enum MetadataReader {
    /// Spotlight attributes for `url`; empty values when the item is not indexed.
    /// All keys are fetched in one `MDItemCopyAttributes` call: each Spotlight call is an IPC round trip to `mds`.
    public static func spotlight(for url: URL) -> SpotlightInfo {
        let keys = [kMDItemDateAdded, kMDItemWhereFroms, kMDItemTitle, kMDItemAuthors, kMDItemContentCreationDate] as CFArray
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
              let values = MDItemCopyAttributes(item, keys) as? [String: Any] else {
            return SpotlightInfo()
        }
        return SpotlightInfo(
            dateAdded: values[kMDItemDateAdded as String] as? Date,
            whereFroms: values[kMDItemWhereFroms as String] as? [String] ?? [],
            title: values[kMDItemTitle as String] as? String,
            authors: values[kMDItemAuthors as String] as? [String] ?? [],
            contentCreationDate: values[kMDItemContentCreationDate as String] as? Date
        )
    }
}
