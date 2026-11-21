import SwiftUI

@main
struct TrimlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Trimly", id: "start") {
            StartView()
        }
        .handlesExternalEvents(matching: [])

        WindowGroup("Plan", id: "plan", for: URL.self) { $root in
            PlanWindow(root: $root)
        }
        .handlesExternalEvents(matching: ["organize"])

        Window("Geçmiş", id: "history") {
            HistoryView()
        }
        .handlesExternalEvents(matching: [])

        Settings {
            SettingsView()
        }
    }
}
