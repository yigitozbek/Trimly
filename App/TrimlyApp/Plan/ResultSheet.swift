import AppKit
import SwiftUI

struct ResultSheet: View {
    let session: PlanSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let run = session.lastRun {
                Text("Taşınan \(run.moved) · atlanan \(run.skipped.count) · hatalı \(run.failed.count)")
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
                Label("Geri alındı: \(undo.restored) öğe, \(undo.removedFolders) klasör kaldırıldı, \(undo.skipped.count) atlandı", systemImage: "arrow.uturn.backward.circle")
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

    private func undo() {
        Task { await session.undoLastApply() }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([session.root])
    }

    private func close() {
        dismiss()
    }
}
