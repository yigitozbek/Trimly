import SwiftUI

struct StringListEditor: View {
    let title: String
    let placeholder: String
    @Binding var items: [String]
    @State private var newItem = ""

    var body: some View {
        Section(title) {
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                        .font(.body.monospaced())
                    Spacer()
                    StringListRemoveButton(item: item, items: $items)
                }
            }
            HStack {
                TextField(placeholder, text: $newItem)
                    .onSubmit(add)
                Button("Ekle", systemImage: "plus", action: add)
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add() {
        let value = newItem.trimmingCharacters(in: .whitespaces)
        guard value.isEmpty == false, items.contains(value) == false else { return }
        items.append(value)
        newItem = ""
    }
}
