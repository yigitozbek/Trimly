import SwiftUI

/// Coloured dot + text for the Ollama state; read as one element by VoiceOver.
struct StatusBadge: View {
    let status: OllamaStatus

    var body: some View {
        Label {
            Text("Ollama: \(status.label)")
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(color)
                .imageScale(.small)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch status {
        case .unknown: .secondary
        case .ready: .green
        case .modelMissing: .yellow
        case .unreachable: .red
        }
    }
}
