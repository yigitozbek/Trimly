import SwiftUI

/// Bottom bar: progress and İptal while working, the outcome afterwards, otherwise a short summary.
struct ProgressFooter: View {
    let session: PlanSession
    let showResult: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch session.phase {
            case .scanning(let progress), .reviewing(let progress):
                if let progress, progress.total > 0 {
                    ProgressView(value: Double(progress.processed), total: Double(progress.total))
                        .frame(maxWidth: 260)
                    Text("LLM \(progress.processed)/\(progress.total)")
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Taranıyor…")
                }
                Spacer()
                Button("İptal", action: session.cancel)
            case .applying:
                ProgressView()
                    .controlSize(.small)
                Text("Uygulanıyor…")
                Spacer()
            case .applied:
                Label("Uygulandı", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Sonucu göster", action: showResult)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Spacer()
            case .idle:
                Text("Onaylı \(session.approvedCount) · karar bekleyen \(session.pendingItems.count)")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
