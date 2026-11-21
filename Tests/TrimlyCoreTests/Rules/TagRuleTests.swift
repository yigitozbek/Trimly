import Foundation
import Testing
@testable import TrimlyCore

struct TagRuleTests {
    func match(_ item: FileItem, mappings: [String: String] = [:]) -> RuleMatch {
        var settings = Settings()
        settings.tagMappings = mappings
        return RuleEngine(settings: settings).match(item)
    }

    @Test func tagWinsOverNamePatterns() {
        let rule = match(.stub("Screenshot 2025-03-14 at 10.22.31.png", tags: ["Fatura"]))
        #expect(rule == RuleMatch(categoryID: "invoices", strength: .decisive, descriptionHint: nil, tag: "Fatura"))
    }

    @Test func mappingIsCaseAndAccentInsensitive() {
        #expect(match(.stub("a.pdf", tags: ["VERGİ"]), mappings: ["Vergi": "invoices"]).categoryID == "invoices")
        #expect(match(.stub("a.pdf", tags: ["sözleşme"])).categoryID == "contracts")
        #expect(match(.stub("a.pdf", tags: ["Resmi Evrak"])).categoryID == "officialDocs")
    }

    @Test func firstMatchingTagWins() {
        #expect(match(.stub("a.pdf", tags: ["Kırmızı", "Sözleşme", "Fatura"])).categoryID == "contracts")
    }

    @Test(.tags(.edgeCase)) func mappingToUnknownCategoryIsIgnored() {
        let rule = match(.stub("download.pdf", tags: ["Vergi"]), mappings: ["Vergi": "yok-boyle"])
        #expect(rule.categoryID == "documents" && rule.tag == nil)
    }
}

@Suite(.tags(.fileSystem))
struct TagPlanningTests {
    @Test(.tags(.edgeCase)) func sensitiveTagMakesItemCritical() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.tagMappings = ["Kimlik": "officialDocs"]
        try TestFS.setTags(["Kimlik"], on: try TestFS.file("a.pdf", in: f.root))
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let item = plan.item("a.pdf")
        #expect(item.categoryID == "officialDocs" && item.critical && item.approved == false)
        #expect(item.reason == "Etiket: Kimlik")
    }

    @Test func taggedFolderSkipsTheLLM() async throws {
        let f = try PlannerFixture(standardFiles: false)
        let folder = try TestFS.folder("Proje", in: f.root)
        try TestFS.file("a.jpg", in: folder)
        try TestFS.file("b.jpg", in: folder)
        try TestFS.setTags(["Fatura"], on: folder)
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        #expect(await mock.requests.contains { $0.request.name == "Proje" } == false)
        #expect(plan.item("Proje").folderMode == .keep && plan.item("Proje").categoryID == "invoices" && plan.item("Proje").status == .review)
    }

    @Test func stageTwoLeavesTaggedItemsAlone() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.tagMappings = ["Kimlik": "officialDocs"]
        try TestFS.setTags(["Kimlik"], on: try TestFS.file("a.pdf", in: f.root))
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler", "Rapor", 0.99))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: false)
        let reviewed = try await f.planner(mock).review(planID: plan.id)
        #expect(reviewed.item("a.pdf").categoryID == "officialDocs")
    }
}
