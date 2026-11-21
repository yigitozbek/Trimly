import SwiftUI
import TrimlyCore

/// Opening window: folder cards (open + multi-select), compact recent runs, status / settings.
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
        VStack(alignment: .leading, spacing: 24) {
            header
            folderSection
            recentSection
            footer
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 440)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder], onCompletion: folderPicked)
        .task(load)
        .onChange(of: launchState.launchedByURL, initial: true) { _, launchedByURL in
            if launchedByURL {
                dismissWindow(id: "start")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trimly")
                .font(.largeTitle.bold())
            Text("Nereyi düzenleyeceksin? Önizleme önce gelir; onayın olmadan hiçbir şey taşınmaz.")
                .foregroundStyle(.secondary)
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FolderCard(
                    title: "Masaüstü",
                    systemImage: "menubar.dock.rectangle",
                    isSelected: $selection.desktop,
                    open: openDesktop
                )
                FolderCard(
                    title: "İndirilenler",
                    systemImage: "arrow.down.circle",
                    isSelected: $selection.downloads,
                    open: openDownloads
                )
                FolderCard(
                    title: "Belgeler",
                    systemImage: "doc",
                    isSelected: $selection.documents,
                    open: openDocuments
                )
            }
            HStack(spacing: 12) {
                if selection.isEmpty == false {
                    Button("Seçilenleri aç (\(selection.urls.count))", systemImage: "rectangle.stack", action: openSelected)
                        .help("Her klasör için ayrı plan penceresi açar.")
                }
                Button("Başka klasör…", systemImage: "folder.badge.plus", action: pickFolder)
                Spacer(minLength: 0)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Son işlemler")
                    .font(.headline)
                Spacer()
                Button("Geçmiş", systemImage: "clock.arrow.circlepath", action: openHistory)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            if let runs {
                if runs.runs.isEmpty {
                    Text("Henüz uygulanmış işlem yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runs.runs) { run in
                        StartRunRow(run: run, model: runs)
                    }
                }
                if let undo = runs.lastUndo {
                    Text("Geri yüklendi: \(undo.restored) öğe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = runs.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            StatusBadge(status: status)
            Spacer()
            SettingsLink {
                Label("Ayarlar…", systemImage: "gearshape")
            }
        }
    }

    private func load() async {
        if runs == nil {
            runs = RunsModel(environment: environment, limit: 3)
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
