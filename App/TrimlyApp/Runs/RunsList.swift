import SwiftUI
import TrimlyCore

struct RunsList: View {
    let model: RunsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.runs.isEmpty {
                Text("Henüz uygulanmış işlem yok.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.runs) { run in
                    row(run)
                }
            }
            if let undo = model.lastUndo {
                Text("Geri yüklenen \(undo.restored) · kaldırılan klasör \(undo.removedFolders) · atlanan \(undo.skipped.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let message = model.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private func row(_ run: RunInfo) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(PathFormatting.displayName(URL(filePath: run.root)))
                Text("\(run.at.formatted(date: .abbreviated, time: .shortened)) · taşınan \(run.moved)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if run.undone {
                Text("Geri alındı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Geri Al", systemImage: "arrow.uturn.backward") {
                    Task { await model.undo(runID: run.runID) }
                }
                .disabled(run.moved == 0)
            }
        }
    }
}
