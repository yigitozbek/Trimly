import AppKit
import Foundation
import QuickLookUI
import TrimlyCore

/// Shows the system Quick Look panel for one file URL (folders / missing paths are ignored).
/// `@unchecked Sendable`: AppKit panel callbacks hop threads; mutable `url` is only set from the main actor before show.
final class QuickLookPresenter: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate, @unchecked Sendable {
    static let shared = QuickLookPresenter()

    private var url: URL?

    /// Previewable file URL for a plan row, or nil for folders / missing files.
    static func previewURL(for item: PlanItem) -> URL? {
        guard item.kind == .file else { return nil }
        guard let url = FinderReveal.url(for: item) else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue == false else {
            return nil
        }
        return url
    }

    @MainActor
    func present(item: PlanItem) {
        guard let url = Self.previewURL(for: item) else { return }
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}
