import Foundation
import Observation
import TrimlyCore

/// Settings window state. Every change is written to `settings.json` immediately (shared with the CLI);
/// existing plans keep their own snapshot, so changes apply to new plans.
@MainActor
@Observable
final class SettingsModel {
    private let environment: AppEnvironment
    var settings: Settings {
        didSet { save() }
    }
    private(set) var saveError: String?
    private(set) var availableModels: [String] = []
    private(set) var status = OllamaStatus.unknown

    init(environment: AppEnvironment) {
        self.environment = environment
        self.settings = environment.loadSettings()
    }

    /// Asked from the settings window even when the LLM is disabled, so models can be picked before enabling it.
    func refreshHealth() async {
        let health = await environment.makeProvider(settings).health()
        availableModels = health.availableModels
        status = .from(health, model: settings.stage1Model)
    }

    /// Live example for a naming preset: `download (3).pdf`, an invoice described as "Enerjisa Ocak", today's date.
    func namingExample(for preset: NamingPreset) -> String {
        let language = settings.categoryLanguage
        return NamingTemplate.fileName(
            preset: preset,
            day: DateResolver.dayString(environment.now()),
            categoryTag: settings.category(id: "invoices")?.tag.value(language) ?? "Fatura",
            description: Self.exampleDescription(for: language),
            originalName: "download (3).pdf",
            fileExtension: "pdf"
        )
    }

    private static func exampleDescription(for language: Language) -> String {
        switch language {
        case .tr: "Enerjisa-Ocak"
        case .en: "Enerjisa-January"
        case .ja: "Enerjisa-1月"
        case .fr: "Enerjisa-Janvier"
        case .it: "Enerjisa-Gennaio"
        case .ko: "Enerjisa-1월"
        }
    }

    private func save() {
        do {
            try SettingsStore.save(settings, to: environment.directory)
            saveError = nil
        } catch {
            saveError = UserMessage.text(for: error)
        }
    }
}
