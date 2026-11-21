import SwiftUI

/// Header of a ready category: tri-state "approve all" button. Never touches critical items (PlanEditor guarantees it).
struct CategoryGroupHeader: View {
    let group: CategoryGroup
    let session: PlanSession

    var body: some View {
        Button(action: toggle) {
            Label {
                Text("\(group.title)  \(group.items.count)")
            } icon: {
                Image(systemName: symbol)
            }
        }
        .buttonStyle(.plain)
        .disabled(session.isReadOnly)
        .accessibilityValue(accessibilityValue)
        .help(group.approval == .all ? "Bu kategorideki tüm öğelerin onayını kaldır" : "Bu kategorideki tüm öğeleri onayla")
    }

    private var symbol: String {
        switch group.approval {
        case .all: "checkmark.square.fill"
        case .none: "square"
        case .mixed: "minus.square.fill"
        }
    }

    private var accessibilityValue: String {
        switch group.approval {
        case .all: "Tümü onaylı"
        case .none: "Hiçbiri onaylı değil"
        case .mixed: "Bazıları onaylı"
        }
    }

    private func toggle() {
        session.setGroupApproved(group.approval != .all, categoryID: group.id)
    }
}
