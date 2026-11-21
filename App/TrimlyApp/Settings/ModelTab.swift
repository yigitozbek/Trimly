import SwiftUI
import TrimlyCore

struct ModelTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Toggle("Yerel LLM kullan (Ollama)", isOn: $model.settings.llmEnabled)
            TextField("Sağlayıcı adresi", text: $model.settings.providerURL)
            ModelPicker(title: "1. aşama modeli", selection: $model.settings.stage1Model, models: model.availableModels)
            ModelPicker(title: "2. aşama modeli", selection: $model.settings.stage2Model, models: model.availableModels)
            LabeledContent("Güven eşiği") {
                HStack {
                    Slider(value: $model.settings.confidenceThreshold, in: 0.5...0.95, step: 0.05)
                    Text(model.settings.confidenceThreshold, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                }
            }
            Stepper("Parti boyutu: \(model.settings.batchSize)", value: $model.settings.batchSize, in: 1...50)
            Toggle("İçerik önizlemesini gönder (kritik dosyalar hariç)", isOn: $model.settings.contentPreview)
            HStack {
                StatusBadge(status: model.status)
                Spacer()
                Button("Yenile", systemImage: "arrow.clockwise", action: refresh)
            }
            SettingsFootnote(error: model.saveError)
        }
        .formStyle(.grouped)
    }

    private func refresh() {
        Task { await model.refreshHealth() }
    }
}
