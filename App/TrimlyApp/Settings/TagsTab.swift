import SwiftUI
import TrimlyCore

/// Finder tag → category mappings. Empty tag names are never saved.
struct TagsTab: View {
    @Bindable var model: SettingsModel
    @State private var draftTag = ""
    @State private var draftCategoryID = "invoices"

    var body: some View {
        Form {
            Section("Etiket → kategori") {
                ForEach(sortedKeys, id: \.self) { key in
                    TagMappingRow(
                        tag: key,
                        categoryID: binding(for: key),
                        categories: categories,
                        onRemove: { remove(key) }
                    )
                }
                HStack {
                    TextField("Etiket adı", text: $draftTag)
                        .onSubmit(add)
                    Picker("Kategori", selection: $draftCategoryID) {
                        ForEach(categories, id: \.id) { category in
                            Text(category.title).tag(category.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    Button("Ekle", systemImage: "plus", action: add)
                        .disabled(draftTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
        .onAppear {
            if categories.contains(where: { $0.id == draftCategoryID }) == false {
                draftCategoryID = categories.first?.id ?? "other"
            }
        }
    }

    private var sortedKeys: [String] {
        model.settings.tagMappings.keys.sorted()
    }

    private var categories: [(id: String, title: String)] {
        let language = model.settings.categoryLanguage
        return model.settings.categories.map { ($0.id, $0.folder.value(language)) }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { model.settings.tagMappings[key] ?? draftCategoryID },
            set: { model.settings.tagMappings[key] = $0 }
        )
    }

    private func add() {
        let tag = draftTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tag.isEmpty == false else { return }
        model.settings.tagMappings[tag] = draftCategoryID
        draftTag = ""
    }

    private func remove(_ key: String) {
        model.settings.tagMappings.removeValue(forKey: key)
    }
}
