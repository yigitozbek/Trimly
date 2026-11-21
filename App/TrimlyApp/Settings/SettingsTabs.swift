import SwiftUI

/// `tabItem` instead of the `Tab` API: the deployment target is macOS 14 and `Tab` needs macOS 15.
struct SettingsTabs: View {
    let model: SettingsModel
    @Binding var selection: SettingsTab

    var body: some View {
        TabView(selection: $selection) {
            NamingTab(model: model)
                .tabItem { Label(SettingsTab.naming.title, systemImage: SettingsTab.naming.systemImage) }
                .tag(SettingsTab.naming)
            TargetTab(model: model)
                .tabItem { Label(SettingsTab.target.title, systemImage: SettingsTab.target.systemImage) }
                .tag(SettingsTab.target)
            TagsTab(model: model)
                .tabItem { Label(SettingsTab.tags.title, systemImage: SettingsTab.tags.systemImage) }
                .tag(SettingsTab.tags)
            TrashTab(model: model)
                .tabItem { Label(SettingsTab.trash.title, systemImage: SettingsTab.trash.systemImage) }
                .tag(SettingsTab.trash)
            ModelTab(model: model)
                .tabItem { Label(SettingsTab.model.title, systemImage: SettingsTab.model.systemImage) }
                .tag(SettingsTab.model)
            IgnoreTab(model: model)
                .tabItem { Label(SettingsTab.ignore.title, systemImage: SettingsTab.ignore.systemImage) }
                .tag(SettingsTab.ignore)
        }
    }
}
