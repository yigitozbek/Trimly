import AppKit
import QuickLookUI
import TrimlyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = LaunchState.shared
        // Every launch starts fresh: restored plan windows would show stale or empty sessions.
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let directory = AppEnvironment.live.directory
        try? directory.ensureExists()
        _ = try? Recovery.recoverAll(in: directory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Masaüstünü Düzenle", action: #selector(organizeDesktop), keyEquivalent: "").target = self
        menu.addItem(withTitle: "İndirilenleri Düzenle", action: #selector(organizeDownloads), keyEquivalent: "").target = self
        return menu
    }

    @objc private func organizeDesktop() {
        NSWorkspace.shared.open(URLRouter.organizeURL(for: .desktopDirectory))
    }

    @objc private func organizeDownloads() {
        NSWorkspace.shared.open(URLRouter.organizeURL(for: .downloadsDirectory))
    }

    // Forward Quick Look panel control to the shared presenter (Space preview).
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        QuickLookPresenter.shared.acceptsPreviewPanelControl(panel)
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLookPresenter.shared.beginPreviewPanelControl(panel)
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLookPresenter.shared.endPreviewPanelControl(panel)
    }
}
