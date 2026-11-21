import SwiftUI
import TrimlyCore

/// Compact recent-run line for the start window (undo via context menu, not a permanent button).
struct StartRunRow: View {
    let run: RunInfo
    let model: RunsModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(PathFormatting.displayName(URL(filePath: run.root)))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            if run.undone == false {
                Button("Geri Al", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(run.moved == 0 && run.tagged == 0 && run.trashed == 0)
            }
        }
        .accessibilityHint(run.undone ? "Geri alındı" : "Geri almak için bağlam menüsü")
    }

    private var summary: String {
        if run.undone {
            return "geri alındı · \(run.at.formatted(date: .omitted, time: .shortened))"
        }
        if let title = run.title, title.isEmpty == false {
            return "\(title) · \(run.at.formatted(date: .omitted, time: .shortened))"
        }
        var parts: [String] = []
        if run.moved > 0 { parts.append("\(run.moved) taşındı") }
        if run.tagged > 0 { parts.append("\(run.tagged) etiket") }
        if run.trashed > 0 { parts.append("\(run.trashed) çöp") }
        if parts.isEmpty { parts.append("işlem yok") }
        parts.append(run.at.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private func undo() {
        Task { await model.undo(runID: run.runID) }
    }
}
