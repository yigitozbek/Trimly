import SwiftUI
import TrimlyCore

/// Category picker and description field of a pending row. Folders have no description (names are only normalized).
struct ItemEditor: View {
    let item: PlanItem
    let categories: [(id: String, title: String)]
    @Binding var categoryID: String
    @Binding var descriptionText: String
    let onSubmitDescription: () -> Void
    @FocusState private var isDescriptionFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Picker("Kategori", selection: $categoryID) {
                ForEach(categories, id: \.id) { category in
                    Text(category.title).tag(category.id)
                }
            }
            .labelsHidden()
            .frame(width: 170)
            if item.kind != .folder {
                TextField("Açıklama", text: $descriptionText)
                    .frame(width: 170)
                    .focused($isDescriptionFocused)
                    .onSubmit(onSubmitDescription)
                    .onChange(of: isDescriptionFocused) { _, focused in
                        if focused == false {
                            onSubmitDescription()
                        }
                    }
            }
        }
    }
}
