import AppKit
import Foundation
import TrimlyCore

/// Opens Finder selecting only paths that still exist (no-op when none do).
enum FinderReveal {
    static func existing(_ urls: [URL]) -> [URL] {
        let fm = FileManager.default
        return urls.filter { fm.fileExists(atPath: $0.path) }
    }

    /// Source if present; otherwise an existing target (post-apply / post-trash).
    static func url(for item: PlanItem) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: item.source.path) {
            return item.source
        }
        if let target = item.target, fm.fileExists(atPath: target.path) {
            return target
        }
        return nil
    }

    /// Prefer still-present move destinations; otherwise the plan root folder.
    static func resultURLs(destinations: [URL], root: URL) -> [URL] {
        let found = existing(destinations)
        return found.isEmpty ? existing([root]) : found
    }

    static func reveal(_ urls: [URL]) {
        let found = existing(urls)
        guard found.isEmpty == false else { return }
        NSWorkspace.shared.activateFileViewerSelecting(found)
    }

    static func reveal(item: PlanItem) {
        guard let url = url(for: item) else { return }
        reveal([url])
    }
}
