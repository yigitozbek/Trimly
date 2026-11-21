import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionAlreadyOrganizedFilterTests {
    @Test func hideAlreadyOrganizedFiltersSkippedGroups() async throws {
        let f = try AppFixture.empty()
        let settings = try SettingsStore.load(from: f.data)
        let root = f.root
        let organized = PlanItem(
            id: "org", name: "2025-02-10_Fatura_Enerjisa.pdf",
            source: root.appending(path: "Faturalar/2025-02-10_Fatura_Enerjisa.pdf"),
            kind: .file, fileExtension: "pdf", resolvedDate: .feb10Midday,
            status: .skipped, skipReason: "Zaten düzenli",
            sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: .feb10Midday),
            relativePath: "Faturalar/2025-02-10_Fatura_Enerjisa.pdf", depth: 1
        )
        let recent = PlanItem(
            id: "rec", name: "new.pdf",
            source: root.appending(path: "new.pdf"),
            kind: .file, fileExtension: "pdf", resolvedDate: .feb10Midday,
            status: .skipped, skipReason: "Son 60 dakikada değişti",
            sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: .feb10Midday)
        )
        let plan = Plan(
            id: "filter-test", root: root, createdAt: Date(), state: .ready,
            settingsSnapshot: settings, items: [organized, recent]
        )
        try PlanStore(directory: f.data).save(plan)
        let session = PlanSession(root: root, environment: f.environment())
        await session.start()
        #expect(session.plan?.id == plan.id)
        #expect(session.hideAlreadyOrganized)
        #expect(session.hiddenAlreadyOrganizedCount == 1)
        #expect(session.skippedGroups.map(\.id) == ["Son 60 dakikada değişti"])
        session.hideAlreadyOrganized = false
        #expect(Set(session.skippedGroups.map(\.id)) == Set(["Zaten düzenli", "Son 60 dakikada değişti"]))
    }

    @Test func isAlreadyOrganizedSkipReasons() {
        #expect(PlanSession.isAlreadyOrganizedSkip("Zaten düzenli"))
        #expect(PlanSession.isAlreadyOrganizedSkip("Zaten etiketli"))
        #expect(PlanSession.isAlreadyOrganizedSkip("Sistem dosyası") == false)
    }
}
