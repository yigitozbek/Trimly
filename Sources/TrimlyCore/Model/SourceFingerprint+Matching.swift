import Foundation

extension SourceFingerprint {
    /// Current fingerprint of the item at `url`, or `nil` if nothing is there. Directories (folders, packages) have `size == nil`.
    public static func read(from url: URL) -> SourceFingerprint? {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
              let modified = values.contentModificationDate else {
            return nil
        }
        let size = values.isDirectory == true ? nil : values.fileSize.map(Int64.init)
        return SourceFingerprint(size: size, modifiedAt: modified)
    }

    /// The single change check used by apply and undo: files must keep their size and mtime (1 s tolerance,
    /// ISO8601 drops fractional seconds); directories only need to exist, because Finder rewrites `.DS_Store`.
    public func matches(_ current: SourceFingerprint) -> Bool {
        guard let size else {
            return true
        }
        return size == current.size && abs(modifiedAt.timeIntervalSince(current.modifiedAt)) < 1.0
    }
}
