import SwiftUI
import TrimlyCore

struct RunRow: View {
    let run: RunInfo
    let model: RunsModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(PathFormatting.displayName(URL(filePath: run.root)))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if run.undone {
                Text("Geri alındı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Geri Al", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(run.moved == 0 && run.tagged == 0)
            }
        }
    }

    private var subtitle: String {
        var parts = ["\(run.at.formatted(date: .abbreviated, time: .shortened))", "taşınan \(run.moved)"]
        if run.tagged > 0 {
            parts.append("etiketlenen \(run.tagged)")
        }
        return parts.joined(separator: " · ")
    }

    private func undo() {
        Task { await model.undo(runID: run.runID) }
    }
}
