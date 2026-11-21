import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct PlannerTests {
    @Test func rulesOnlyPlanWithoutLLM() async throws {
        let f = try PlannerFixture()
        let mock = MockLLMProvider()
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: false)

        let shot = plan.item("Screenshot 2025-03-14 at 10.22.31.png")
        #expect(shot.status == .ready && shot.decidedBy == .rule && shot.approved)
        #expect(shot.target?.path == f.root.appending(path: "Ekran-Goruntuleri/2025-03-14_Ekran-Goruntusu_10-22-31.png").path)
        let pdf = plan.item("download (3).pdf")
        #expect(pdf.status == .review && pdf.reviewReason == .weakRuleNoLLM && pdf.confidence == 0.6 && pdf.categoryID == "documents" && pdf.approved == false)
        #expect(plan.item("cert.der").status == .critical && plan.item("cert.der").approved == false)
        #expect(plan.item(".DS_Store").skipReason == "Sistem dosyası")
        #expect(plan.item("myproj").skipReason == "Proje klasörü (.git)")
        #expect(plan.item("Album").reviewReason == .folder && plan.item("Album").approved == false)
        #expect(await mock.requests.isEmpty)
        #expect(plan.state == .ready)
        // ISO8601 drops sub-second precision, so compare what matters rather than whole-plan equality.
        #expect(try f.store.load(id: plan.id).items.map(\.target) == plan.items.map(\.target))
    }

    @Test func llmClassifiesWeakItems() async throws {
        let f = try PlannerFixture()
        let mock = MockLLMProvider(
            results: ["download (3).pdf": PlannerFixture.result("Faturalar", "Enerjisa Ocak 2025-01-31.pdf", 0.91, "Fatura no")],
            defaultResult: PlannerFixture.result("Belgeler")
        )
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)

        let pdf = plan.item("download (3).pdf")
        #expect(pdf.status == .ready && pdf.decidedBy == .llm1 && pdf.approved)
        #expect(pdf.target?.lastPathComponent == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(pdf.target?.deletingLastPathComponent().lastPathComponent == "Faturalar")
        let sent = try #require(await mock.requests.first { $0.request.name == "download (3).pdf" })
        #expect(sent.model == "qwen3:4b")
        #expect(sent.request.contentPreview == "Fatura No 123")
        #expect(sent.request.allowedFolders.contains("Faturalar"))
    }

    @Test func lowConfidenceGoesToReview() async throws {
        let f = try PlannerFixture()
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Faturalar", "Enerjisa", 0.5))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        let pdf = plan.item("download (3).pdf")
        #expect(pdf.status == .review && pdf.reviewReason == .lowConfidence && pdf.approved == false)
    }

    @Test func criticalContentNeverSent() async throws {
        let f = try PlannerFixture()
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Resmi-Evrak", "Kimlik", 0.99))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)

        let sent = try #require(await mock.requests.first { $0.request.name == "kimlik.pdf" })
        #expect(sent.request.contentPreview == nil)
        #expect(plan.item("kimlik.pdf").status == .critical && plan.item("kimlik.pdf").approved == false)
        #expect(await mock.requests.contains { $0.request.name == "cert.der" } == false)
    }

    @Test func llmSensitiveCategoryMakesItemCritical() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try TestFS.file("notlar.md", in: f.root, contents: "toplanti notlari")
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Sertifika-Anahtar", "Anahtar", 0.95))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        #expect(plan.item("notlar.md").status == .critical && plan.item("notlar.md").approved == false)
    }

    @Test func secretMarkersBlockPreviewAndMarkCritical() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try TestFS.file("servis.json", in: f.root, contents: #"{"type":"service_account","private_key":"-----BEGIN PRIVATE KEY-----\nABC"}"#)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Veri", "Servis Hesabi", 0.95))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        let sent = try #require(await mock.requests.first { $0.request.name == "servis.json" })
        #expect(sent.request.contentPreview == nil)
        #expect(plan.item("servis.json").status == .critical && plan.item("servis.json").approved == false)
    }

    @Test func providerFailureFallsBack() async throws {
        let f = try PlannerFixture()
        let mock = MockLLMProvider(defaultResult: .failure(LLMError.unreachable))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        let pdf = plan.item("download (3).pdf")
        #expect(pdf.status == .review && pdf.reviewReason == .llmError && pdf.categoryID == "documents")
        #expect(plan.item("Screenshot 2025-03-14 at 10.22.31.png").status == .ready)
    }

    @Test func checkpointsEveryBatchAndResumes() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.batchSize = 2
        for i in 1...5 { try TestFS.file("belge\(i).pdf", in: f.root) }

        let first = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"), cancelAfterCalls: 3)
        await #expect(throws: CancellationError.self) {
            try await f.planner(first).makePlan(root: f.root, useLLM: true)
        }
        let saved = try #require(try f.store.latestResumable(root: f.root, now: Date()))
        #expect(saved.items.filter { $0.decidedBy == .llm1 }.count == 2)

        let second = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        let plan = try await f.planner(second).makePlan(root: f.root, useLLM: true)
        #expect(plan.id == saved.id)
        #expect(await second.requests.count == 3)
        #expect(plan.state == .ready)
    }

    @Test func makePlanWithoutResumeIgnoresCheckpoint() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.batchSize = 2
        for i in 1...5 { try TestFS.file("belge\(i).pdf", in: f.root) }
        let cancelling = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"), cancelAfterCalls: 3)
        await #expect(throws: CancellationError.self) {
            try await f.planner(cancelling).makePlan(root: f.root, useLLM: true)
        }
        let checkpoint = try #require(try f.store.latestResumable(root: f.root, now: Date()))
        let fresh = try await f.planner(MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))).makePlan(root: f.root, useLLM: true, resume: false)
        #expect(fresh.id != checkpoint.id)
    }

    @Test(.tags(.edgeCase)) func checkpointFromOlderEngineOrOtherSettingsIsNotResumed() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try TestFS.file("a.pdf", in: f.root)
        var oldEngine = Plan(id: "old-engine", root: f.root, createdAt: Date(), state: .inProgress, settingsSnapshot: f.settings, items: [])
        oldEngine.engineVersion = nil
        try f.store.save(oldEngine)
        #expect(try await f.planner(nil).makePlan(root: f.root, useLLM: false).id != "old-engine")

        var otherSettings = f.settings
        otherSettings.namingPreset = .keepOriginal
        try f.store.save(Plan(id: "other-settings", root: f.root, createdAt: Date(), state: .inProgress, settingsSnapshot: otherSettings, items: []))
        #expect(try await f.planner(nil).makePlan(root: f.root, useLLM: false).id != "other-settings")
    }

    @Test func plansWithoutEngineVersionDecodeAsNotReusable() throws {
        let root = try TestFS.tempDir()
        let plan = Plan.stub(root: root, items: [])
        var json = try JSONSerialization.jsonObject(with: JSONCoding.encoder.encode(plan)) as! [String: Any]
        json.removeValue(forKey: "engineVersion")
        let decoded = try JSONCoding.decoder.decode(Plan.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.engineVersion == nil)
        #expect(decoded.isReusable(with: Settings()) == false)
        #expect(plan.isReusable(with: Settings()))
    }

    @Test func resumeOnlyWithin24Hours() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try TestFS.file("a.pdf", in: f.root)
        let stale = Plan(id: "stale", root: f.root, createdAt: Date().addingTimeInterval(-25 * 3600), state: .inProgress, settingsSnapshot: f.settings, items: [])
        try f.store.save(stale)
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.id != "stale")
    }

    @Test func statsCountsByReason() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let stats = Planner.stats(plan)
        #expect(stats.total == 8 && stats.skipped == 2 && stats.critical == 2 && stats.ready == 2 && stats.review == 2)
        #expect(stats.reviewByReason == ["weakRuleNoLLM": 1, "folder": 1])
        #expect(stats.sentToLLM == 0)
        // screenshot, song, cert.der are decisive; kimlik.pdf is a weak-rule fallback (0.6) even though it is critical.
        #expect(stats.decisiveRule == 3)
        #expect(stats.topReviewPatterns.first == PatternCount(pattern: ".pdf", count: 1))
    }

    @Test(.tags(.edgeCase)) func emojiOnlyNameFallsBack() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try TestFS.file("🔥🔥.png", in: f.root)
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item("🔥🔥.png").target?.lastPathComponent.hasSuffix("_Gorsel_Dosya.png") == true)
    }
}
