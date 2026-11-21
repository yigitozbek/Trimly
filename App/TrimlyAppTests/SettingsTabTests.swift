import Foundation
import Testing
@testable import TrimlyApp

struct SettingsTabTests {
    @Test func rawValuesAreStableForDeepLinks() {
        #expect(SettingsTab.naming.rawValue == "naming")
        #expect(SettingsTab.tags.rawValue == "tags")
        #expect(SettingsTab.ignore.rawValue == "ignore")
        #expect(SettingsTab.storageKey == "settingsTab")
    }

    @Test func selectWritesTabForDeepLink() {
        UserDefaults.standard.removeObject(forKey: SettingsTab.storageKey)
        SettingsOpener.select(.ignore)
        #expect(UserDefaults.standard.string(forKey: SettingsTab.storageKey) == SettingsTab.ignore.rawValue)
        SettingsOpener.select(.tags)
        #expect(UserDefaults.standard.string(forKey: SettingsTab.storageKey) == SettingsTab.tags.rawValue)
    }
}
