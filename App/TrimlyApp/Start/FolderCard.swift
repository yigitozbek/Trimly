import SwiftUI

/// Large start-screen target: primary click opens the folder; checkbox selects it for “Seçilenleri aç”.
struct FolderCard: View {
    let title: String
    let systemImage: String
    @Binding var isSelected: Bool
    let open: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: open) {
                VStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .medium))
                        .frame(height: 32)
                    Text(title)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 88)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Toggle(isOn: $isSelected) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .padding(10)
            .help("Birlikte açmak için seç")
        }
    }
}
