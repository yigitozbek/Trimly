import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

/// Regression tests for the Phase 2 final review findings.
@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionReviewFixTests {
    let shotName = "Screenshot 2025-03-14 at 10.22.31.png"

    func stage2Session(_ f: AppFixture, gate: Gate, mock: MockLLMProvider) async throws -> PlanSession {
        let session = PlanSession(root: f.root, environment: f.environment(provider: GatedProvider(gate: gate, wrapped: mock)))
        await session.start()
        try f.writeSettings { $0.llmEnabled = true }
        await session.refreshHealth()
        return session
    }

    @Test(.tags(.edgeCase)) func editsAreRejectedWhileStage2Runs() async throws {
        let f = try AppFixture.standard()
        let gate = Gate()
        let session = try await stage2Session(f, gate: gate, mock: MockLLMProvider(defaultResult: AppFixture.result("Faturalar", "Enerjisa Ocak", 0.9)))
        let critical = try f.item("kimlik.pdf", in: session.plan).id
        session.setApproved(true, for: critical)
        let stage2 = Task { await session.runStage2() }
        await gate.waitUntilEntered()
        #expect(session.isBusy)
        session.setApproved(false, for: critical)
        session.setApproved(false, for: try f.item("song.mp3", in: session.plan).id)
        #expect(session.errorMessage == "Bir işlem sürüyor; bitince tekrar deneyin.")
        await gate.release()
        await stage2.value
        let planID = try #require(session.plan?.id)
        let saved = try PlanStore(directory: f.data).load(id: planID)
        #expect(try f.item("kimlik.pdf", in: saved).approved && f.item("song.mp3", in: saved).approved)
    }

    @Test func cancelStopsStage2() async throws {
        let f = try AppFixture.standard()
        let gate = Gate()
        let mock = MockLLMProvider(defaultResult: AppFixture.result("Faturalar", "Enerjisa Ocak", 0.9))
        let session = try await stage2Session(f, gate: gate, mock: mock)
        let stage2 = Task { await session.runStage2() }
        await gate.waitUntilEntered()
        session.cancel()
        await gate.release()
        await stage2.value
        #expect(await mock.requests.isEmpty)
        #expect(try f.item("download (3).pdf", in: session.plan).decidedBy == .rule)
        #expect(session.phase == .idle)
    }

    @Test func groupHeaderOnlyTouchesItsGroup() async throws {
        let f = try AppFixture.empty()
        try f.writeSettings { $0.llmEnabled = true }
        try TestFS.file("ozet.pdf", in: f.root)
        try TestFS.file("taslak.pdf", in: f.root)
        let mock = MockLLMProvider(results: ["ozet.pdf": AppFixture.result("Belgeler", "Ozet", 0.9), "taslak.pdf": AppFixture.result("Belgeler", "Taslak", 0.5)])
        let session = PlanSession(root: f.root, environment: f.environment(provider: HealthyProvider(wrapping: mock)))
        await session.start()
        session.setGroupApproved(false, categoryID: "documents")
        session.setGroupApproved(true, categoryID: "documents")
        #expect(try f.item("taslak.pdf", in: session.plan).approved == false)
        session.setApproved(true, for: try f.item("taslak.pdf", in: session.plan).id)
        session.setGroupApproved(false, categoryID: "documents")
        #expect(try f.item("taslak.pdf", in: session.plan).approved)
    }

    @Test func rescanStartsFreshAndCancelledScanCanResume() async throws {
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
        #expect(first.canResume)
        let checkpoint = try #require(try PlanStore(directory: f.data).latestResumable(root: f.root, now: Date()))

        try f.writeSettings { $0.namingPreset = .keepOriginal }
        let second = PlanSession(root: f.root, environment: f.environment(provider: HealthyProvider(wrapping: MockLLMProvider(defaultResult: AppFixture.result("Belgeler")))))
        await second.rescan()
        #expect(second.plan?.id != checkpoint.id)
        #expect(try f.item("belge1.pdf", in: second.plan).target?.lastPathComponent == "belge1.pdf")
    }

    @Test func nextApplyClearsPreviousUndo() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        await session.apply(confirming: session.applySummary)
        await session.undoLastApply()
        #expect(session.lastUndo != nil)
        await session.rescan()
        #expect(session.lastUndo == nil && session.lastRun == nil)
        await session.apply(confirming: session.applySummary)
        #expect(session.lastUndo == nil)
    }

    @Test func editedPendingItemStaysInPendingSection() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        session.setCategory("invoices", for: try f.item("download (3).pdf", in: session.plan).id)
        #expect(session.pendingItems.map(\.name).contains("download (3).pdf"))
        #expect(session.readyGroups.contains { $0.id == "invoices" } == false)
    }

    @Test func failedEditBumpsRevision() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        let planID = try #require(session.plan?.id)
        _ = try await Executor(directory: f.data).apply(planID: planID)
        let before = session.revision
        session.setApproved(true, for: try f.item("kimlik.pdf", in: session.plan).id)
        #expect(session.revision > before)
    }

    @Test(.tags(.edgeCase)) func applyRefusesWhenApprovalsChangedElsewhere() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        let summary = session.applySummary
        let store = PlanStore(directory: f.data)
        var onDisk = try store.load(id: try #require(session.plan?.id))
        try PlanEditor.set(&onDisk, itemID: try f.item("kimlik.pdf", in: onDisk).id, categoryID: nil, description: nil, approve: true)
        try store.save(onDisk)

        await session.apply(confirming: summary)
        #expect(session.lastRun == nil)
        #expect(session.errorMessage == "Plan başka bir yerde değiştirildi; onay özetini yeniden kontrol edin.")
        #expect(FileManager.default.fileExists(atPath: f.root.appending(path: shotName).path))
        #expect(try f.item("kimlik.pdf", in: session.plan).approved)
    }

    @Test func rescanIsIgnoredWhileStarting() async throws {
        let f = try AppFixture.standard()
        try f.writeSettings { $0.llmEnabled = true }
        let gate = Gate()
        let session = PlanSession(root: f.root, environment: f.environment(provider: SlowHealthProvider(gate: gate)))
        let start = Task { await session.start() }
        await gate.waitUntilEntered()
        #expect(session.isBusy)
        await session.rescan()
        await gate.release()
        await start.value
        let plans = try PlanStore(directory: f.data).list().filter { $0.root.standardizedFileURL.path == f.root.standardizedFileURL.path }
        #expect(plans.count == 1)
    }

    @Test func rescanRefreshesOllamaHealth() async throws {
        let f = try AppFixture.standard()
        try f.writeSettings { $0.llmEnabled = true }
        let provider = SwitchableProvider(wrapping: MockLLMProvider(defaultResult: AppFixture.result("Faturalar", "Enerjisa Ocak", 0.9)), reachable: false)
        let session = PlanSession(root: f.root, environment: f.environment(provider: provider))
        await session.start()
        #expect(session.banner != nil)
        await provider.setReachable(true)
        await session.rescan()
        #expect(session.banner == nil)
        #expect(try f.item("download (3).pdf", in: session.plan).decidedBy == .llm1)
    }

    @Test func appTestsUseTemporaryDataDirectory() {
        #expect(AppEnvironment.live.directory.root.standardizedFileURL.path != DataDirectory.default.root.standardizedFileURL.path)
    }
}
