import SwiftUI
import TrimlyCore

/// One Finder-tag → category mapping row in Settings › Etiketler.
struct TagMappingRow: View {
    let tag: String
    @Binding var categoryID: String
    let categories: [(id: String, title: String)]
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text(tag)
                .font(.body.monospaced())
            Spacer()
            Picker("Kategori", selection: $categoryID) {
                ForEach(categories, id: \.id) { category in
                    Text(category.title).tag(category.id)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            Button("Kaldır", systemImage: "minus.circle", action: onRemove)
                .labelStyle(.iconOnly)
        }
    }
}
