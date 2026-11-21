import Foundation

/// Result of a depth-limited scan: items in breadth-first order, and whether the item limit stopped it early.
public struct ScanTree: Sendable {
    public let items: [FileItem]
    public let truncated: Bool

    public init(items: [FileItem], truncated: Bool) {
        self.items = items
        self.truncated = truncated
    }
}
