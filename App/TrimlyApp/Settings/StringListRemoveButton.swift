import SwiftUI

struct StringListRemoveButton: View {
    let item: String
    @Binding var items: [String]

    var body: some View {
        Button("\(item) kaldır", systemImage: "minus.circle", action: remove)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
    }

    private func remove() {
        items.removeAll { $0 == item }
    }
}
