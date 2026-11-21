import AppKit
import Foundation
import SwiftUI

/// Selects a Settings tab (via `AppStorage`) and opens the Settings scene.
enum SettingsOpener {
    /// Persists the tab so `SettingsView` opens on (or switches to) it.
    static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: SettingsTab.storageKey)
    }

    /// Opens Settings after `select`. Prefer `@Environment(\.openSettings)` from a View; this is the AppKit fallback.
    @MainActor
    static func openWindow() {
        let selector = Selector(("showSettingsWindow:"))
        if NSApp.sendAction(selector, to: nil, from: nil) == false {
            // Older / edge paths: try ordering any existing settings-like window, then the selector again after activate.
            NSApp.activate(ignoringOtherApps: true)
            _ = NSApp.sendAction(selector, to: nil, from: nil)
        }
    }

    /// Convenience when no `OpenSettingsAction` is in scope (tests, AppKit callers).
    @MainActor
    static func open(_ tab: SettingsTab) {
        select(tab)
        openWindow()
    }
}
