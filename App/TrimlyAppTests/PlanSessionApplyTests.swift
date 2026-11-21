import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionApplyTests {
    let shotName = "Screenshot 2025-03-14 at 10.22.31.png"

    func startedSession(_ f: AppFixture, provider: (any LLMProvider)? = nil) async -> PlanSession {
        let session = PlanSession(root: f.root, environment: f.environment(provider: provider))
        await session.start()
        return session
    }

    @Test func applyMovesApprovedAndBecomesReadOnly() async throws {
        let f = try AppFixture.standard()
        let session = await startedSession(f)
        await session.apply()
        let run = try #require(session.lastRun)
        #expect(session.phase == .applied(runID: run.runID))
        #expect(run.moved == 2 && session.isReadOnly)
        #expect(FileManager.default.fileExists(atPath: f.root.appending(path: "Ekran-Goruntuleri/2025-03-14_Ekran-Goruntusu_10-22-31.png").path))
    }

    @Test(.tags(.edgeCase)) func applyReportsVanishedSource() async throws {
        let f = try AppFixture.standard()
        let session = await startedSession(f)
        let song = f.root.appending(path: "song.mp3")
        try FileManager.default.removeItem(at: song)
        await session.apply()
        #expect(session.lastRun?.skipped.contains(SkippedEntry(path: song.path, reason: "Kaynak bulunamadı")) == true)
        if case .applied = session.phase {} else { Issue.record("phase \(session.phase) should be .applied") }
    }

    @Test func undoAfterApplyRestores() async throws {
        let f = try AppFixture.standard()
        let session = await startedSession(f)
        await session.apply()
        await session.undoLastApply()
        #expect(session.lastUndo?.restored == 2)
        #expect(FileManager.default.fileExists(atPath: f.root.appending(path: shotName).path))
    }

    @Test func applyWhileLockedFails() async throws {
        let f = try AppFixture.standard()
        let session = await startedSession(f)
        let lock = try DataLock.acquire(in: f.data)
        await session.apply()
        #expect(session.phase == .failed("Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin."))
        withExtendedLifetime(lock) {}
    }

    @Test func stage2PromotesAndNeverTouchesApproved() async throws {
        let f = try AppFixture.standard()
        let provider = HealthyProvider(wrapping: MockLLMProvider(defaultResult: AppFixture.result("Faturalar", "Enerjisa Ocak", 0.9)))
        let session = await startedSession(f, provider: provider)
        #expect(session.stage2Available == false)

        try f.writeSettings { $0.llmEnabled = true }
        await session.refreshHealth()
        let critical = try f.item("kimlik.pdf", in: session.plan)
        session.setApproved(true, for: critical.id)
        #expect(session.stage2Available)

        await session.runStage2()
        let invoice = try f.item("download (3).pdf", in: session.plan)
        #expect(invoice.status == .ready && invoice.approved && invoice.decidedBy == .llm2)
        #expect(try f.item("kimlik.pdf", in: session.plan).target == critical.target)
        #expect(session.phase == .idle)
    }

    @Test func applySummaryListsCriticalApprovals() async throws {
        let f = try AppFixture.standard()
        let session = await startedSession(f)
        session.setApproved(true, for: try f.item("kimlik.pdf", in: session.plan).id)
        let summary = session.applySummary
        #expect(summary.criticalApproved.map(\.name) == ["kimlik.pdf"])
        #expect(summary.count == session.approvedCount)
        #expect(summary.byCategory.map(\.count).reduce(0, +) == summary.count)
    }
}
