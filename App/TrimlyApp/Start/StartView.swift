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
                ShortcutButton(title: "Masaüstü", systemImage: "menubar.dock.rectangle", action: openDesktop)
                ShortcutButton(title: "İndirilenler", systemImage: "arrow.down.circle", action: openDownloads)
                ShortcutButton(title: "Klasör seç…", systemImage: "folder.badge.plus", action: pickFolder)
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
                Button("Geçmiş", systemImage: "clock.arrow.circlepath", action: openHistory)
                SettingsLink {
                    Label("Ayarlar…", systemImage: "gearshape")
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder], onCompletion: folderPicked)
        .task(load)
    }

    private func load() async {
        if runs == nil {
            runs = RunsModel(environment: environment, limit: 5)
        }
        runs?.refresh()
        let settings = environment.loadSettings()
        let health = await environment.makeProvider(settings).health()
        status = .from(health, model: settings.stage1Model)
    }

    private func openDesktop() {
        open(.desktopDirectory)
    }

    private func openDownloads() {
        open(.downloadsDirectory)
    }

    private func pickFolder() {
        isPickingFolder = true
    }

    private func openHistory() {
        openWindow(id: "history")
    }

    private func folderPicked(_ result: Result<URL, any Error>) {
        if case .success(let folder) = result {
            open(folder)
        }
    }

    private func open(_ folder: URL) {
        openWindow(id: "plan", value: folder.standardizedFileURL)
    }
}
