import AppKit
import Foundation

/// Writes the desired Settings tab then asks the app to show the Settings window.
enum SettingsOpener {
    static func open(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: SettingsTab.storageKey)
        // Standard macOS Settings scene action (SwiftUI Settings { }).
        let selector = Selector(("showSettingsWindow:"))
        if NSApp.responds(to: selector) {
            NSApp.sendAction(selector, to: nil, from: nil)
        }
    }
}
