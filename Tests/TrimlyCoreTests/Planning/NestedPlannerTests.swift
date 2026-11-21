import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct NestedPlannerTests {
    func tree(_ f: PlannerFixture, _ files: [String]) throws {
        for path in files {
            let url = f.root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TestFS.file(url.lastPathComponent, in: url.deletingLastPathComponent())
        }
    }

    @Test func mixedFolderIsDistributedAndUniformFolderKept() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/c.dmg"] + (1...5).map { "Tatil/\($0).jpg" })
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item("Rastgele").folderMode == .distribute && plan.item("Rastgele").reviewReason == .mixedFolder)
        #expect(plan.item("Rastgele").categoryID != nil)
        #expect(plan.item(path: "Rastgele/b.jpg").covered == false && plan.item(path: "Rastgele/b.jpg").target != nil)
        #expect(plan.item("Tatil").folderMode == .keep)
        #expect(plan.item(path: "Tatil/1.jpg").covered && plan.item(path: "Tatil/1.jpg").approved == false)
    }

    @Test func inPlaceCategoryFolderContentsAreAlreadyOrganized() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Faturalar/2025-02-10_Fatura_Enerjisa.pdf"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item(path: "Faturalar/2025-02-10_Fatura_Enerjisa.pdf").skipReason == "Zaten düzenli")
        #expect(plan.item("Faturalar").skipReason == Planner.categoryFolderReason)
    }

    @Test func centralModeMigratesCategoryFolderContents() async throws {
        var f = try PlannerFixture(standardFiles: false)
        let archive = try TestFS.tempDir()
        f.settings.targetMode = .central
        f.settings.archiveRoot = archive.path
        try tree(f, ["Faturalar/2025-02-10_Fatura_Enerjisa.pdf"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let item = plan.item(path: "Faturalar/2025-02-10_Fatura_Enerjisa.pdf")
        #expect(item.status == .ready && item.approved)
        #expect(item.target?.path == archive.appending(path: "Faturalar/2025-02-10_Fatura_Enerjisa.pdf").path)
    }

    @Test(.tags(.edgeCase)) func scanningTheArchiveItselfProposesNothing() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.targetMode = .central
        f.settings.archiveRoot = f.root.path
        f.settings.yearSubfolders = true
        try tree(f, ["Faturalar/2025/2025-02-10_Fatura_Enerjisa.pdf"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item(path: "Faturalar/2025/2025-02-10_Fatura_Enerjisa.pdf").skipReason == "Zaten düzenli")
        #expect(plan.item(path: "Faturalar/2025").skipReason == Planner.yearFolderReason)
        #expect(plan.items.contains { $0.approved } == false)
    }

    @Test(.tags(.edgeCase)) func folderWithRecentOrPartialChildCannotMoveAsUnit() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, (1...4).map { "Indirme/\($0).jpg" } + ["Indirme/x.crdownload"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item("Indirme").folderMode == .distribute)
        #expect(plan.item(path: "Indirme/x.crdownload").skipReason == "Yarım indirme")
    }

    @Test func projectSubfolderIsNotEntered() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Rastgele/proj/.git/HEAD", "Rastgele/proj/a.txt", "Rastgele/b.pdf"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.items.contains { $0.relativePath == "Rastgele/proj/a.txt" } == false)
        #expect(plan.item(path: "Rastgele/proj").skipReason == "Proje klasörü (.git)")
        // A folder must not carry a project along when it moves as one unit.
        #expect(plan.item("Rastgele").folderMode == .distribute)
    }

    @Test func coveredItemsNeverReachTheLLM() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, (1...5).map { "Tatil/\($0).jpg" } + ["Tatil/notlar.txt", "Rastgele/a.pdf", "Rastgele/b.jpg"])
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        let asked = await mock.requests.map(\.request)
        #expect(asked.contains { $0.name == "notlar.txt" } == false)
        #expect(asked.first { $0.name == "a.pdf" }?.relativePath == "Rastgele/a.pdf")
        #expect(plan.item(path: "Tatil/notlar.txt").covered)
    }

    @Test func criticalStaysCriticalAtDepth() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Rastgele/kimlik.pdf", "Rastgele/b.jpg"])
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler", "Kimlik", 0.99))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        let item = plan.item(path: "Rastgele/kimlik.pdf")
        #expect(item.status == .critical && item.approved == false)
        #expect(await mock.requests.first { $0.request.name == "kimlik.pdf" }?.request.contentPreview == nil)
    }
}
