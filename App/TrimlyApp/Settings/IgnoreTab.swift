import SwiftUI
import TrimlyCore

struct IgnoreTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Toggle("Gizli dosyaları atla", isOn: $model.settings.ignoreHidden)
            Toggle("Uygulama paketlerini (.app) atla", isOn: $model.settings.ignoreApps)
            Stepper("Son \(model.settings.recentMinutes) dakikada değişenleri atla", value: $model.settings.recentMinutes, in: 0...1440, step: 15)
            StringListEditor(title: "Hariç tutma kalıpları (glob)", placeholder: "*.tmp", items: $model.settings.ignoreGlobs)
            StringListEditor(title: "Proje klasörü işaretleri", placeholder: "package.json", items: $model.settings.projectMarkers)
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
    }
}
