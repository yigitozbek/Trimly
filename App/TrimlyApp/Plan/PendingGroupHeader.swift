import SwiftUI
import TrimlyCore

/// Heading row of a mixed folder's pending rows: the folder stays in place; its mode can be switched here.
struct PendingGroupHeader: View {
    let folder: PlanItem
    let session: PlanSession

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.relativePath)
                    .font(.headline)
                if let lock = folder.modeLock {
                    Label("Tek parça taşınamaz: \(lock). İçindekiler tek tek düzenlenir.", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Karışık klasör: içindekiler tek tek düzenlenir, klasör yerinde kalır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if session.isReadOnly == false && folder.modeLock == nil {
                FolderModePicker(item: folder, session: session)
            }
        }
        .padding(.top, 6)
    }
}
