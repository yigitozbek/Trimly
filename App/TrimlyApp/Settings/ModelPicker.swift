import SwiftUI

/// Picker over installed models; falls back to a text field when Ollama could not be asked.
struct ModelPicker: View {
    let title: String
    @Binding var selection: String
    let models: [String]

    var body: some View {
        if models.isEmpty {
            TextField(title, text: $selection)
        } else {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
    }

    private var options: [String] {
        models.contains(selection) ? models : [selection] + models
    }
}
