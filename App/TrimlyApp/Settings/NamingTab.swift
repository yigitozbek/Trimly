import SwiftUI
import TrimlyCore

struct NamingTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Picker("Adlandırma biçimi", selection: $model.settings.namingPreset) {
                ForEach(NamingPreset.allCases, id: \.self) { preset in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.title)
                        Text(model.namingExample(for: preset))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.radioGroup)
            Picker("Kategori dili", selection: $model.settings.categoryLanguage) {
                Text("Türkçe").tag(Language.tr)
                Text("English").tag(Language.en)
            }
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
    }
}
