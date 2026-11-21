import AppKit
import TrimlyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
}
