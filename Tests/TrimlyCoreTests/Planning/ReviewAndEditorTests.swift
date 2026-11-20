import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct ReviewAndEditorTests {
    func rulesOnlyPlan(_ f: PlannerFixture) async throws -> Plan {
        try await f.planner(nil).makePlan(root: f.root, useLLM: false)
    }

    // MARK: Stage 2

    @Test func reviewUnloadsStage1ThenUsesStage2() async throws {
        let f = try PlannerFixture()
        let plan = try await rulesOnlyPlan(f)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        _ = try await f.planner(mock).review(planID: plan.id)
        let events = await mock.events
        #expect(events.first == "unload:qwen3:4b")
        #expect(events.dropFirst().isEmpty == false)
        #expect(events.dropFirst().allSatisfy { $0.hasPrefix("classify:ministral-3:14b:") })
    }

    @Test func reviewPromotesConfidentItems() async throws {
        let f = try PlannerFixture()
        let plan = try await rulesOnlyPlan(f)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Faturalar", "Enerjisa Ocak", 0.9))
        let reviewed = try await f.planner(mock).review(planID: plan.id)
        let pdf = reviewed.item("download (3).pdf")
        #expect(pdf.status == .ready && pdf.decidedBy == .llm2 && pdf.approved)
        #expect(pdf.target?.lastPathComponent == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(try f.store.load(id: plan.id).item("download (3).pdf").decidedBy == .llm2)
    }

    @Test func reviewNeverApprovesCritical() async throws {
        let f = try PlannerFixture()
        let plan = try await rulesOnlyPlan(f)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Resmi-Evrak", "Kimlik Fotokopisi", 0.99))
        let reviewed = try await f.planner(mock).review(planID: plan.id)
        let id = reviewed.item("kimlik.pdf")
        #expect(id.status == .critical && id.approved == false && id.decidedBy == .llm2 && id.categoryID == "officialDocs")
        let sent = try #require(await mock.requests.first { $0.request.name == "kimlik.pdf" })
        #expect(sent.request.contentPreview == nil)
    }

    @Test func reviewSendsLongerPreview() async throws {
        let f = try PlannerFixture()
        try TestFS.file("uzun.txt", in: f.root, contents: String(repeating: "b", count: 5000))
        let plan = try await rulesOnlyPlan(f)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        _ = try await f.planner(mock).review(planID: plan.id)
        let sent = try #require(await mock.requests.first { $0.request.name == "uzun.txt" })
        #expect(sent.request.contentPreview?.count == 4000)
    }

    @Test func reviewRejectsAppliedPlan() async throws {
        let f = try PlannerFixture()
        var plan = try await rulesOnlyPlan(f)
        plan.state = .applied
        try f.store.save(plan)
        await #expect(throws: PlanError.alreadyApplied) {
            try await f.planner(MockLLMProvider()).review(planID: plan.id)
        }
    }

    // MARK: Editing

    @Test func setManualCategoryRecomputesTarget() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [.stub("download (3).pdf", in: root, category: "documents", status: .review, reviewReason: .weakRuleNoLLM)])
        let id = plan.item("download (3).pdf").id
        try PlanEditor.set(&plan, itemID: id, categoryID: "invoices", description: "Kira Ocak", approve: true)
        let item = plan.item("download (3).pdf")
        #expect(item.decidedBy == .manual && item.status == .ready && item.reviewReason == nil && item.approved)
        #expect(item.target?.deletingLastPathComponent().lastPathComponent == "Faturalar")
        #expect(item.target?.lastPathComponent.contains("_Fatura_Kira-Ocak") == true)
    }

    @Test func setOnCriticalKeepsStatusButAllowsExplicitApprove() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [.stub("kimlik.pdf", in: root, category: "officialDocs", status: .critical, critical: true)])
        try PlanEditor.set(&plan, itemID: plan.item("kimlik.pdf").id, categoryID: nil, description: nil, approve: true)
        #expect(plan.item("kimlik.pdf").status == .critical && plan.item("kimlik.pdf").approved)
    }

    @Test func setRejectsUnknownCategoryAndItem() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [.stub("a.pdf", in: root, category: "documents")])
        let id = plan.item("a.pdf").id
        #expect(throws: PlanError.unknownCategory("yok")) {
            try PlanEditor.set(&plan, itemID: id, categoryID: "yok", description: nil, approve: nil)
        }
        #expect(throws: PlanError.itemNotFound("zzz")) {
            try PlanEditor.set(&plan, itemID: "zzz", categoryID: nil, description: nil, approve: true)
        }
    }

    @Test(.tags(.edgeCase)) func unskippedCriticalItemStaysCritical() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.recentMinutes = 60
        try TestFS.file("kimlik_on.pdf", in: f.root, modified: Date(), created: Date())
        var plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let id = plan.item("kimlik_on.pdf").id
        #expect(plan.item("kimlik_on.pdf").status == .skipped)
        try PlanEditor.set(&plan, itemID: id, categoryID: "officialDocs", description: nil, approve: nil)
        #expect(plan.item("kimlik_on.pdf").status == .critical)
        #expect(PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: false) == 0)
    }

    @Test func reviewLeavesApprovedItemsAlone() async throws {
        let f = try PlannerFixture()
        var plan = try await rulesOnlyPlan(f)
        let critical = plan.item("kimlik.pdf")
        try PlanEditor.set(&plan, itemID: critical.id, categoryID: nil, description: nil, approve: true)
        _ = PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: false)
        try f.store.save(plan)
        let before = try f.store.load(id: plan.id)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Saglik", "Tahlil Sonucu", 0.99))

        let reviewed = try await f.planner(mock).review(planID: plan.id)

        #expect(reviewed.item("kimlik.pdf").target == before.item("kimlik.pdf").target)
        #expect(reviewed.item("download (3).pdf").target == before.item("download (3).pdf").target)
        let asked = await mock.requests.map(\.request.name)
        #expect(asked.contains("kimlik.pdf") == false && asked.contains("download (3).pdf") == false)
    }

    @Test func bulkApproveSkipsCriticalAndFolders() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [
            .stub("a.pdf", in: root, category: "documents", status: .review, confidence: 0.6, reviewReason: .weakRuleNoLLM),
            .stub("b.pdf", in: root, category: "documents", status: .review, confidence: 0.5, reviewReason: .lowConfidence),
            .stub("kimlik.pdf", in: root, category: "officialDocs", status: .critical, critical: true),
            .stub("Album", in: root, category: "images", kind: .folder, status: .review, reviewReason: .folder)
        ])
        TargetAssigner.assign(&plan)
        #expect(PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: false) == 2)
        #expect(plan.item("kimlik.pdf").approved == false && plan.item("Album").approved == false)
        #expect(PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: true) == 1)
        #expect(plan.item("kimlik.pdf").approved == false)
    }

    @Test func bulkApproveFilters() throws {
        let root = try TestFS.tempDir()
        let items: [PlanItem] = [
            .stub("a.pdf", in: root, category: "documents", status: .review, confidence: 0.9, reviewReason: .lowConfidence),
            .stub("b.pdf", in: root, category: "documents", status: .review, confidence: 0.6, reviewReason: .weakRuleNoLLM),
            .stub("c.jpg", in: root, category: "images", status: .review, confidence: 0.6, reviewReason: .llmError)
        ]
        var byConfidence = Plan.stub(root: root, items: items)
        TargetAssigner.assign(&byConfidence)
        #expect(PlanEditor.bulkApprove(&byConfidence, categoryID: nil, reviewReason: nil, minConfidence: 0.8, includeFolders: false) == 1)
        #expect(byConfidence.item("a.pdf").approved)

        var byReason = Plan.stub(root: root, items: items)
        TargetAssigner.assign(&byReason)
        #expect(PlanEditor.bulkApprove(&byReason, categoryID: nil, reviewReason: .llmError, minConfidence: nil, includeFolders: false) == 1)
        #expect(byReason.item("c.jpg").approved)

        var byCategory = Plan.stub(root: root, items: items)
        TargetAssigner.assign(&byCategory)
        #expect(PlanEditor.bulkApprove(&byCategory, categoryID: "documents", reviewReason: nil, minConfidence: nil, includeFolders: false) == 2)
        #expect(byCategory.item("c.jpg").approved == false)
    }
}
