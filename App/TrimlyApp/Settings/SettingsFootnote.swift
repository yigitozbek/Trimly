import SwiftUI

struct SettingsFootnote: View {
    let error: String?

    var body: some View {
        if let error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Text("Değişiklikler hemen kaydedilir ve yeni planlarda geçerli olur.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
