import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionTests {
    @Test func scanBuildsSections() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.phase == .idle && session.plan?.state == .ready)
        #expect(session.pendingItems.map(\.name) == ["Album", "download (3).pdf", "kimlik.pdf"])
        #expect(session.readyGroups.map(\.id).sorted() == ["audio", "screenshots"])
        #expect(session.skippedGroups.map(\.id) == ["Sistem dosyası"])
        #expect(session.approvedCount == 2)
        #expect(session.banner == nil)
    }

    @Test func loadsExistingReadyPlanInsteadOfRescanning() async throws {
        let f = try AppFixture.standard()
        let store = PlanStore(directory: f.data)
        var plan = try await Planner(settings: f.environment().loadSettings(), store: store, provider: nil).makePlan(root: f.root, useLLM: false)
        let shot = try f.item("Screenshot 2025-03-14 at 10.22.31.png", in: plan)
        try PlanEditor.set(&plan, itemID: shot.id, categoryID: nil, description: nil, approve: false)
        try store.save(plan)

        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.plan?.id == plan.id)
        #expect(try f.item("Screenshot 2025-03-14 at 10.22.31.png", in: session.plan).approved == false)
    }

    @Test(.tags(.edgeCase)) func startRescansWhenSavedPlanUsesOtherSettingsOrOlderEngine() async throws {
        let f = try AppFixture.standard()
        let store = PlanStore(directory: f.data)
        let saved = try await Planner(settings: f.environment().loadSettings(), store: store, provider: nil).makePlan(root: f.root, useLLM: false)
        try f.writeSettings { $0.namingPreset = .keepOriginal }
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.plan?.id != saved.id)
        #expect(try f.item("Screenshot 2025-03-14 at 10.22.31.png", in: session.plan).target?.lastPathComponent == "Screenshot 2025-03-14 at 10.22.31.png")

        var oldEngine = try #require(session.plan)
        oldEngine.engineVersion = nil
        try store.save(oldEngine)
        let reopened = PlanSession(root: f.root, environment: f.environment())
        await reopened.start()
        #expect(reopened.plan?.id != oldEngine.id)
    }

    @Test(.tags(.edgeCase)) func startIsIdempotent() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        async let first: Void = session.start()
        async let second: Void = session.start()
        _ = await (first, second)
        let plans = try PlanStore(directory: f.data).list().filter { $0.root.standardizedFileURL.path == f.root.standardizedFileURL.path }
        #expect(plans.count == 1)
    }

    @Test func searchFiltersPendingItems() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        session.searchText = "KİM"
        #expect(session.pendingItems.map(\.name) == ["kimlik.pdf"])
    }

    @Test func editsPersistToDisk() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        let id = try f.item("download (3).pdf", in: session.plan).id
        session.setCategory("invoices", for: id)
        session.setDescription("Kira Ocak", for: id)
        session.setApproved(true, for: id)

        let planID = try #require(session.plan?.id)
        let saved = try f.item("download (3).pdf", in: try PlanStore(directory: f.data).load(id: planID))
        #expect(saved.decidedBy == .manual && saved.approved)
        #expect(saved.target?.lastPathComponent.hasSuffix("_Fatura_Kira-Ocak.pdf") == true)
        #expect(session.errorMessage == nil)
    }

    @Test func groupToggleNeverApprovesCritical() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        session.setGroupApproved(false, categoryID: "screenshots")
        #expect(session.readyGroups.first { $0.id == "screenshots" }?.approval == ApprovalState.none)
        session.setGroupApproved(true, categoryID: "screenshots")
        #expect(session.readyGroups.first { $0.id == "screenshots" }?.approval == .all)
        #expect(try f.item("kimlik.pdf", in: session.plan).approved == false)
    }

    @Test func selectAllPendingSkipsCritical() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.pendingApproval == ApprovalState.none && session.selectablePendingCount == 2)
        session.setPendingApproved(true)
        #expect(try f.item("Album", in: session.plan).approved && f.item("download (3).pdf", in: session.plan).approved)
        #expect(try f.item("kimlik.pdf", in: session.plan).approved == false)
        #expect(session.pendingApproval == .all)
        session.setPendingApproved(false)
        #expect(session.pendingApproval == ApprovalState.none)
    }

    @Test func selectAllPendingRespectsSearch() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        session.searchText = "down"
        session.setPendingApproved(true)
        #expect(try f.item("download (3).pdf", in: session.plan).approved)
        #expect(try f.item("Album", in: session.plan).approved == false)
    }

    @Test(.tags(.edgeCase)) func editAfterExternalApplyShowsError() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        let planID = try #require(session.plan?.id)
        _ = try await Executor(directory: f.data).apply(planID: planID)
        session.setApproved(true, for: try f.item("kimlik.pdf", in: session.plan).id)
        #expect(session.errorMessage == "Bu plan zaten uygulanmış; yeni bir plan oluşturun.")
        #expect(session.isReadOnly)
    }

    @Test(.tags(.edgeCase)) func providerFailureKeepsSessionUsable() async throws {
        let f = try AppFixture.standard()
        try f.writeSettings { $0.llmEnabled = true }
        let provider = HealthyProvider(wrapping: MockLLMProvider(defaultResult: .failure(LLMError.unreachable)))
        let session = PlanSession(root: f.root, environment: f.environment(provider: provider))
        await session.start()
        #expect(session.phase == .idle && session.banner == nil)
        #expect(try f.item("download (3).pdf", in: session.plan).reviewReason == .llmError)
    }

    @Test func unreachableOllamaShowsBannerAndUsesRules() async throws {
        let f = try AppFixture.standard()
        try f.writeSettings { $0.llmEnabled = true }
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.banner == "Ollama erişilemiyor; yalnızca kurallar kullanılıyor.")
        #expect(try f.item("download (3).pdf", in: session.plan).reviewReason == .weakRuleNoLLM)
    }

    @Test func cancellationKeepsCheckpointAndResumes() async throws {
        let f = try AppFixture.empty()
        try f.writeSettings { settings in
            settings.llmEnabled = true
            settings.batchSize = 2
        }
        for index in 1...5 {
            try TestFS.file("belge\(index).pdf", in: f.root)
        }
        let cancelling = HealthyProvider(wrapping: MockLLMProvider(defaultResult: AppFixture.result("Belgeler"), cancelAfterCalls: 3))
        let first = PlanSession(root: f.root, environment: f.environment(provider: cancelling))
        await first.start()
        #expect(first.phase == .idle && first.errorMessage == nil && first.plan == nil)
        let checkpoint = try #require(try PlanStore(directory: f.data).latestResumable(root: f.root, now: Date()))

        let healthy = HealthyProvider(wrapping: MockLLMProvider(defaultResult: AppFixture.result("Belgeler")))
        let second = PlanSession(root: f.root, environment: f.environment(provider: healthy))
        await second.start()
        #expect(second.plan?.id == checkpoint.id && second.plan?.state == .ready)
    }
}
