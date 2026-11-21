import SwiftUI
import TrimlyCore

struct TrashTab: View {
    @Bindable var model: SettingsModel

    private static let disabledAge = 10_000

    var body: some View {
        Form {
            Toggle("Eski kurulum dosyaları", isOn: installerEnabled)
            if model.settings.trashInstallerAgeDays > 0, model.settings.trashInstallerAgeDays < Self.disabledAge {
                Stepper(
                    "\(model.settings.trashInstallerAgeDays) günden eski",
                    value: $model.settings.trashInstallerAgeDays,
                    in: 1...365
                )
            }
            Toggle("Bayat yarım indirmeler", isOn: partialEnabled)
            if model.settings.trashPartialDownloadAgeDays > 0,
               model.settings.trashPartialDownloadAgeDays < Self.disabledAge {
                Stepper(
                    "\(model.settings.trashPartialDownloadAgeDays) günden eski",
                    value: $model.settings.trashPartialDownloadAgeDays,
                    in: 1...30
                )
            }
            Toggle("Özdeş kopyalar", isOn: $model.settings.trashDuplicates)
            Toggle("Boş dosyalar", isOn: $model.settings.trashEmptyFiles)
            Toggle("Geçici dosyalar", isOn: $model.settings.trashTempFiles)
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
    }

    private var installerEnabled: Binding<Bool> {
        Binding(
            get: { model.settings.trashInstallerAgeDays < Self.disabledAge },
            set: { on in
                model.settings.trashInstallerAgeDays = on
                    ? (model.settings.trashInstallerAgeDays < Self.disabledAge
                        ? model.settings.trashInstallerAgeDays : 30)
                    : Self.disabledAge
            }
        )
    }

    private var partialEnabled: Binding<Bool> {
        Binding(
            get: { model.settings.trashPartialDownloadAgeDays < Self.disabledAge },
            set: { on in
                model.settings.trashPartialDownloadAgeDays = on
                    ? (model.settings.trashPartialDownloadAgeDays < Self.disabledAge
                        ? model.settings.trashPartialDownloadAgeDays : 1)
                    : Self.disabledAge
            }
        )
    }
}
