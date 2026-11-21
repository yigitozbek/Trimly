import SwiftUI

/// Shown after İptal: the scan's checkpoint can be resumed, or a fresh plan started.
struct ResumeRow: View {
    let resume: () -> Void
    let rescan: () -> Void

    var body: some View {
        HStack {
            Label("Tarama durduruldu; kaldığı yer kaydedildi.", systemImage: "pause.circle")
            Spacer()
            Button("Devam et", systemImage: "play.fill", action: resume)
            Button("Baştan tara", systemImage: "arrow.clockwise", action: rescan)
        }
    }
}
