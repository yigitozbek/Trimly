import Foundation

/// Result of a depth-limited scan: items in breadth-first order, and whether the item limit stopped it early.
public struct ScanTree: Sendable {
    public let items: [FileItem]
    public let truncated: Bool
    /// Relative paths of the folders whose contents were listed completely.
    public let descended: Set<String>

    public init(items: [FileItem], truncated: Bool, descended: Set<String> = []) {
        self.items = items
        self.truncated = truncated
        self.descended = descended
    }
}
