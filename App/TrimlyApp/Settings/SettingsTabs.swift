import SwiftUI

/// `tabItem` instead of the `Tab` API: the deployment target is macOS 14 and `Tab` needs macOS 15.
struct SettingsTabs: View {
    let model: SettingsModel

    var body: some View {
        TabView {
            NamingTab(model: model)
                .tabItem { Label("Adlandırma", systemImage: "textformat") }
            TargetTab(model: model)
                .tabItem { Label("Hedef", systemImage: "folder") }
            TagsTab(model: model)
                .tabItem { Label("Etiketler", systemImage: "tag") }
            ModelTab(model: model)
                .tabItem { Label("Model", systemImage: "cpu") }
            IgnoreTab(model: model)
                .tabItem { Label("Hariç tutma", systemImage: "eye.slash") }
        }
    }
}
