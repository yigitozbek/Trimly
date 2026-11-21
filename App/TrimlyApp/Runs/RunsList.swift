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
                    RunRow(run: run, model: model)
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
}
