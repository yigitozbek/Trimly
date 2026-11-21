import SwiftUI

struct HistoryCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Geçmiş", action: openHistory)
            .keyboardShortcut("y")
    }

    private func openHistory() {
        openWindow(id: "history")
    }
}
