import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct SettingsModelTests {
    @Test func changesAreSavedImmediately() throws {
        let f = try AppFixture.empty()
        let model = SettingsModel(environment: f.environment())
        model.settings.namingPreset = .categoryDescription
        #expect(try SettingsStore.load(from: f.data).namingPreset == .categoryDescription)
        #expect(model.saveError == nil)
    }

    @Test func namingExamplesFollowPresetAndLanguage() throws {
        let f = try AppFixture.empty()
        let model = SettingsModel(environment: f.environment(now: .feb10Midday))
        #expect(model.namingExample(for: .dateCategoryDescription) == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(model.namingExample(for: .keepOriginal) == "download (3).pdf")
        model.settings.categoryLanguage = .en
        #expect(model.namingExample(for: .categoryDescription) == "Invoice_Enerjisa-January.pdf")
    }

    @Test(.tags(.edgeCase)) func rescanUsesUpdatedSettings() async throws {
        let f = try AppFixture.standard()
        let shot = "Screenshot 2025-03-14 at 10.22.31.png"
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        let before = try f.item(shot, in: session.plan).target
        #expect(before?.lastPathComponent == "2025-03-14_Ekran-Goruntusu_10-22-31.png")

        let model = SettingsModel(environment: f.environment())
        model.settings.namingPreset = .keepOriginal
        #expect(try f.item(shot, in: session.plan).target == before)

        await session.rescan()
        #expect(try f.item(shot, in: session.plan).target?.lastPathComponent == shot)
    }

    @Test func healthPopulatesModels() async throws {
        let f = try AppFixture.empty()
        let model = SettingsModel(environment: f.environment(provider: HealthyProvider(wrapping: MockLLMProvider())))
        await model.refreshHealth()
        #expect(model.status == .ready)
        #expect(model.availableModels == ["qwen3:4b", "ministral-3:14b"])
    }
}
