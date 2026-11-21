import SwiftUI

struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @AppStorage(SettingsTab.storageKey) private var tabRaw = SettingsTab.naming.rawValue
    @State private var model: SettingsModel?

    private var selection: Binding<SettingsTab> {
        Binding(
            get: { SettingsTab(rawValue: tabRaw) ?? .naming },
            set: { tabRaw = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if let model {
                SettingsTabs(model: model, selection: selection)
            } else {
                ProgressView()
            }
        }
        .frame(width: 600, height: 460)
        .task(load)
    }

    private func load() async {
        if model == nil {
            model = SettingsModel(environment: environment)
        }
        await model?.refreshHealth()
    }
}
