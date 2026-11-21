import SwiftUI
import TrimlyCore

struct ItemStatusIcon: View {
    let item: PlanItem

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .frame(width: 18)
            .accessibilityLabel(ItemFormatting.statusLabel(item))
    }

    private var symbol: String {
        switch item.status {
        case .critical: "lock.fill"
        case .review: item.kind == .folder ? "folder" : "questionmark.circle"
        case .ready: "checkmark.circle"
        case .skipped: "minus.circle"
        }
    }

    private var color: Color {
        switch item.status {
        case .critical: .red
        case .review: .orange
        case .ready: .green
        case .skipped: .secondary
        }
    }
}
