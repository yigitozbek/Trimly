import Foundation
import Testing
@testable import TrimlyCore

struct SettingsTests {
    @Test func defaultsMatchSpec() {
        let s = Settings()
        #expect(s.stage1Model == "qwen3:4b" && s.stage2Model == "ministral-3:14b")
        #expect(s.confidenceThreshold == 0.75 && s.batchSize == 10 && s.recentMinutes == 60)
        #expect(s.namingPreset == .dateCategoryDescription && s.targetMode == .inPlace)
        #expect(s.archiveRoot == "~/Documents/Arsiv" && s.yearSubfolders == false)
        #expect(s.categories.count == 22 && s.categoryLanguage == .tr)
        #expect(s.scanDepth == 5 && s.distributeThreshold == 0.8 && s.removeEmptyFolders == false)
        #expect(s.addCategoryTags && s.tagMappings.isEmpty)
        #expect(s.trashInstallerAgeDays == 30 && s.trashPartialDownloadAgeDays == 1)
        #expect(s.trashDuplicates && s.trashEmptyFiles && s.trashTempFiles)
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let s = try JSONCoding.decoder.decode(Settings.self, from: Data(#"{"stage1Model":"gemma3:4b"}"#.utf8))
        #expect(s.stage1Model == "gemma3:4b" && s.confidenceThreshold == 0.75)
    }

    @Test func storeReturnsDefaultsWhenMissingAndRoundTrips() throws {
        let dir = DataDirectory(root: try TestFS.tempDir())
        #expect(try SettingsStore.load(from: dir) == Settings())
        var s = Settings()
        s.batchSize = 3
        try SettingsStore.save(s, to: dir)
        #expect(try SettingsStore.load(from: dir).batchSize == 3)
    }

    @Test func categoryLookup() {
        let s = Settings()
        #expect(s.category(id: "invoices")?.folder.tr == "Faturalar")
        #expect(s.category(id: "invoices")?.tag.en == "Invoice")
        #expect(s.category(id: "invoices")?.folder.ja == "請求書")
        #expect(s.category(id: "invoices")?.folder.fr == "Factures")
        #expect(s.category(id: "invoices")?.folder.it == "Fatture")
        #expect(s.category(id: "invoices")?.folder.ko == "청구서")
        #expect(s.category(forFolderName: "faturalar")?.id == "invoices")
        #expect(s.category(forFolderName: "Invoices")?.id == "invoices")
        #expect(s.category(forFolderName: "請求書")?.id == "invoices")
        #expect(s.category(forFolderName: "Factures")?.id == "invoices")
        #expect(s.allCategoryFolderNames.contains("ekran-goruntuleri"))
        #expect(s.allCategoryFolderNames.contains("스크린샷"))
    }

    @Test func localizedTextFallsBackForLegacyJSON() throws {
        let data = Data(#"{"tr":"Faturalar","en":"Invoices"}"#.utf8)
        let text = try JSONCoding.decoder.decode(LocalizedText.self, from: data)
        #expect(text.tr == "Faturalar" && text.en == "Invoices")
        #expect(text.ja == "Invoices" && text.fr == "Invoices")
        #expect(text.it == "Invoices" && text.ko == "Invoices")
        #expect(Language.allCases.map(\.rawValue) == ["tr", "en", "ja", "fr", "it", "ko"])
    }

    @Test func planRoundTripsThroughJSON() throws {
        let item = PlanItem(
            id: "a1b2c3d4",
            name: "download (3).pdf",
            source: URL(filePath: "/tmp/r/download (3).pdf"),
            kind: .file,
            fileExtension: "pdf",
            resolvedDate: Date(timeIntervalSince1970: 1_739_188_800),
            categoryID: "invoices",
            description: "Enerjisa-Ocak",
            target: URL(filePath: "/tmp/r/Faturalar/2025-02-10_Fatura_Enerjisa-Ocak.pdf"),
            confidence: 0.91,
            reason: "Fatura no",
            decidedBy: .llm1,
            status: .ready,
            reviewReason: nil,
            skipReason: nil,
            critical: false,
            approved: true,
            classified: true,
            sourceFingerprint: SourceFingerprint(size: 48_213, modifiedAt: Date(timeIntervalSince1970: 1_739_188_800))
        )
        let plan = Plan(
            id: "2026-11-21T14-03-22_Downloads",
            root: URL(filePath: "/tmp/r"),
            createdAt: Date(timeIntervalSince1970: 1_763_733_802),
            state: .ready,
            appliedRunID: nil,
            settingsSnapshot: Settings(),
            items: [item]
        )
        let data = try JSONCoding.encoder.encode(plan)
        #expect(try JSONCoding.decoder.decode(Plan.self, from: data) == plan)
    }
}
