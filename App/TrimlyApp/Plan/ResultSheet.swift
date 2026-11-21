import AppKit
import SwiftUI
import TrimlyCore

struct ResultSheet: View {
    let session: PlanSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let run = session.lastRun {
                Text(runSummary(run))
                    .font(.title3.bold())
                if run.skipped.isEmpty == false || run.failed.isEmpty == false {
                    GroupBox("Ayrıntılar") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(run.skipped + run.failed, id: \.path) { entry in
                                Text("\(URL(filePath: entry.path).lastPathComponent) — \(entry.reason)")
                                    .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let undo = session.lastUndo {
                Label(undoSummary(undo), systemImage: "arrow.uturn.backward.circle")
            }
            HStack {
                Button("Geri Al", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(session.lastUndo != nil)
                Button("Finder'da göster", systemImage: "folder", action: revealInFinder)
                Spacer()
                Button("Kapat", action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func runSummary(_ run: RunSummary) -> String {
        var parts = ["Taşınan \(run.moved)"]
        if run.tagged > 0 {
            parts.append("etiketlenen \(run.tagged)")
        }
        parts.append("atlanan \(run.skipped.count)")
        parts.append("hatalı \(run.failed.count)")
        return parts.joined(separator: " · ")
    }

    private func undoSummary(_ undo: UndoSummary) -> String {
        var parts = ["Geri alındı: \(undo.restored) öğe"]
        if undo.restoredTags > 0 {
            parts.append("\(undo.restoredTags) etiket geri alındı")
        }
        parts.append("\(undo.removedFolders) klasör kaldırıldı")
        parts.append("\(undo.skipped.count) atlandı")
        return parts.joined(separator: ", ")
    }

    private func undo() {
        Task { await session.undoLastApply() }
    }

    private func revealInFinder() {
        let destinations = session.plan?.items.compactMap { item -> URL? in
            guard item.approved, let target = item.target else { return nil }
            return target
        } ?? []
        FinderReveal.reveal(FinderReveal.resultURLs(destinations: destinations, root: session.root))
    }

    private func close() {
        dismiss()
    }
}
