import SwiftUI
import TrimlyCore

/// Opening window: shortcuts for Desktop / Downloads / any folder, the last runs and the Ollama status.
struct StartView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.openWindow) private var openWindow
    @State private var runs: RunsModel?
    @State private var status = OllamaStatus.unknown
    @State private var isPickingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trimly")
                    .font(.largeTitle.bold())
                Text("Bir klasör seç; önce önizleme gösterilir, hiçbir şey onayın olmadan taşınmaz.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                shortcut("Masaüstü", systemImage: "menubar.dock.rectangle") { open(.desktopDirectory) }
                shortcut("İndirilenler", systemImage: "arrow.down.circle") { open(.downloadsDirectory) }
                shortcut("Klasör seç…", systemImage: "folder.badge.plus") { isPickingFolder = true }
            }

            GroupBox("Son işlemler") {
                if let runs {
                    RunsList(model: runs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
            }

            HStack {
                StatusBadge(status: status)
                Spacer()
                Button("Geçmiş", systemImage: "clock.arrow.circlepath") {
                    openWindow(id: "history")
                }
                SettingsLink {
                    Label("Ayarlar…", systemImage: "gearshape")
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result {
                open(folder)
            }
        }
        .task {
            if runs == nil {
                runs = RunsModel(environment: environment, limit: 5)
            }
            runs?.refresh()
            let settings = environment.loadSettings()
            let health = await environment.makeProvider(settings).health()
            status = .from(health, model: settings.stage1Model)
        }
    }

    private func shortcut(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .controlSize(.large)
    }

    private func open(_ folder: URL) {
        openWindow(id: "plan", value: folder.standardizedFileURL)
    }
}
