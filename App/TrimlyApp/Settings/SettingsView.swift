import SwiftUI

struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: SettingsModel?

    var body: some View {
        Group {
            if let model {
                SettingsTabs(model: model)
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
