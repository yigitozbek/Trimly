import SwiftUI
import TrimlyCore

/// Opening window: shortcuts for Desktop / Downloads / Documents / any folder, multi-select chips, last runs, Ollama status.
struct StartView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    private let launchState = LaunchState.shared
    @State private var runs: RunsModel?
    @State private var status = OllamaStatus.unknown
    @State private var isPickingFolder = false
    @State private var selection = FolderPickerSelection()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trimly")
                    .font(.largeTitle.bold())
                Text("Klasör seç veya birkaçını işaretle; önce önizleme gösterilir, hiçbir şey onayın olmadan taşınmaz.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ShortcutButton(title: "Masaüstü", systemImage: "menubar.dock.rectangle", action: openDesktop)
                ShortcutButton(title: "İndirilenler", systemImage: "arrow.down.circle", action: openDownloads)
                ShortcutButton(title: "Belgeler", systemImage: "doc", action: openDocuments)
                ShortcutButton(title: "Klasör seç…", systemImage: "folder.badge.plus", action: pickFolder)
            }

            GroupBox("Birlikte aç") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 16) {
                        Toggle("Masaüstü", isOn: $selection.desktop)
                        Toggle("İndirilenler", isOn: $selection.downloads)
                        Toggle("Belgeler", isOn: $selection.documents)
                    }
                    .toggleStyle(.checkbox)
                    Button("Seçilenleri aç", systemImage: "rectangle.stack", action: openSelected)
                        .disabled(selection.isEmpty)
                        .help("Her klasör için ayrı plan penceresi açar.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
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
        .frame(minWidth: 560, minHeight: 480)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder], onCompletion: folderPicked)
        .task(load)
        .onChange(of: launchState.launchedByURL, initial: true) { _, launchedByURL in
            // The plan window already exists when this flips, so the app never passes through zero windows.
            if launchedByURL {
                dismissWindow(id: "start")
            }
        }
    }

    private func load() async {
        if runs == nil {
            runs = RunsModel(environment: environment, limit: 5)
        }
        await runs?.refresh()
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

    private func openDocuments() {
        open(.documentsDirectory)
    }

    private func openSelected() {
        for folder in selection.urls {
            open(folder)
        }
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
