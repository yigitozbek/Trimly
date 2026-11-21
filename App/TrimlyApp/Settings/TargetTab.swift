import SwiftUI
import TrimlyCore

struct TargetTab: View {
    @Bindable var model: SettingsModel
    @State private var isPickingArchive = false

    var body: some View {
        Form {
            Picker("Düzenlenen dosyalar", selection: $model.settings.targetMode) {
                Text("Klasörün içinde kategori klasörlerine").tag(TargetMode.inPlace)
                Text("Merkezi arşive").tag(TargetMode.central)
            }
            .pickerStyle(.radioGroup)
            if model.settings.targetMode == .central {
                LabeledContent("Arşiv klasörü") {
                    HStack {
                        Text(model.settings.archiveRoot)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Seç…", action: pickArchive)
                    }
                }
            }
            Toggle("Yıl alt klasörü kullan (ör. Faturalar/2025)", isOn: $model.settings.yearSubfolders)
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isPickingArchive, allowedContentTypes: [.folder], onCompletion: archivePicked)
    }

    private func pickArchive() {
        isPickingArchive = true
    }

    private func archivePicked(_ result: Result<URL, any Error>) {
        if case .success(let folder) = result {
            model.settings.archiveRoot = folder.path
        }
    }
}
