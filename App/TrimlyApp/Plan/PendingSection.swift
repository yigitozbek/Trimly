import SwiftUI

struct PendingSection: View {
    let session: PlanSession

    var body: some View {
        Section {
            if session.pendingItems.isEmpty && session.pendingGroups.isEmpty {
                Text("Karar bekleyen öğe yok.")
                    .foregroundStyle(.secondary)
            }
            ForEach(session.pendingGroups) { group in
                if let folder = group.folder {
                    PendingGroupHeader(folder: folder, session: session)
                }
                ForEach(group.items) { item in
                    ItemRow(item: item, session: session, isEditable: session.isReadOnly == false)
                        .padding(.leading, group.folder == nil ? 0 : 18)
                }
            }
        } header: {
            PendingSectionHeader(session: session)
        }
    }
}
