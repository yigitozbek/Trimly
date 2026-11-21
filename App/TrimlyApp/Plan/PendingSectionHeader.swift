import SwiftUI

/// Section title with "Tümünü seç / Tümünü kaldır" over the visible rows. Critical rows are never included;
/// they can only be approved one by one.
struct PendingSectionHeader: View {
    let session: PlanSession

    var body: some View {
        HStack {
            Text("Karar bekleyen (\(session.pendingItems.count))")
            Spacer()
            Button(action: toggle) {
                Label(title, systemImage: symbol)
            }
            .buttonStyle(.borderless)
            .disabled(session.selectablePendingCount == 0 || session.isReadOnly || session.isBusy)
            .help("Görünen öğeleri seçer. Kritik (🔒) öğeler dahil edilmez; onları tek tek onaylayın.")
        }
    }

    private var title: String {
        session.pendingApproval == .all ? "Tümünü kaldır" : "Tümünü seç (\(session.selectablePendingCount))"
    }

    private var symbol: String {
        switch session.pendingApproval {
        case .all: "checkmark.square.fill"
        case .none: "square"
        case .mixed: "minus.square.fill"
        }
    }

    private func toggle() {
        session.setPendingApproved(session.pendingApproval != .all)
    }
}
