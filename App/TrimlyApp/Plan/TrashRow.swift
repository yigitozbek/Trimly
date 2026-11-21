import SwiftUI
import TrimlyCore

struct TrashRow: View {
    let item: PlanItem
    let session: PlanSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                if let reason = item.trashReason {
                    Text(reason.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let runID = item.trashedRunID {
                Text("Çöp Kutusu'nda")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Geri Al", systemImage: "arrow.uturn.backward") {
                    Task { await session.undoTrash(runID: runID) }
                }
                .disabled(session.isBusy)
            } else {
                Button("Çöp Kutusu'na at", systemImage: "trash") {
                    Task { await session.trash(item) }
                }
                .disabled(session.isBusy || session.isReadOnly)
            }
        }
    }
}
