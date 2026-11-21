import SwiftUI

/// Opens the Settings scene on a specific tab using the system `openSettings` action.
struct OpenSettingsButton: View {
    let title: String
    var systemImage: String? = nil
    let tab: SettingsTab

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: open) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
    }

    private func open() {
        SettingsOpener.select(tab)
        openSettings()
    }
}
