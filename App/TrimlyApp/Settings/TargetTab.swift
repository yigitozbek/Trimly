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
            Stepper("Tarama derinliği: \(model.settings.scanDepth) seviye", value: $model.settings.scanDepth, in: 1...5)
                .help("1: yalnızca klasörün kendi içi. 3: iki alt klasör seviyesine kadar iner. Proje klasörlerine hiç girilmez.")
            Toggle("Yalnızca boş kalan klasörleri kaldır", isOn: $model.settings.removeEmptyFolders)
                .help("Bir düzenlemenin boşalttığı klasörler kaldırılır, Geri Al onları yeniden oluşturur. Önceden boş olan klasörlere dokunulmaz.")
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
