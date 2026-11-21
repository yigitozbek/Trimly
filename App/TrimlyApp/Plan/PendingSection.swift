import SwiftUI

struct PendingSection: View {
    let session: PlanSession

    var body: some View {
        Section {
            if session.pendingItems.isEmpty {
                Text("Karar bekleyen öğe yok.")
                    .foregroundStyle(.secondary)
            }
            ForEach(session.pendingItems) { item in
                ItemRow(item: item, session: session, isEditable: session.isReadOnly == false)
            }
        } header: {
            PendingSectionHeader(session: session)
        }
    }
}
