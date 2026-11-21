import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct NestedPlannerTests {
    func tree(_ f: PlannerFixture, _ files: [String]) throws {
        for path in files {
            let url = f.root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Unique bytes so TrashDetector does not mark same-size stubs as duplicates.
            try TestFS.file(url.lastPathComponent, in: url.deletingLastPathComponent(), contents: path)
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
        // Fresh partial: older defaults would be stale Trash candidates and would not pin the folder.
        let partial = f.root.appending(path: "Indirme/x.crdownload")
        try FileManager.default.setAttributes([.creationDate: Date(), .modificationDate: Date()], ofItemAtPath: partial.path)
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

    /// Review C1: the pin is stored, so the folder can never be switched to keep and moved with what pins it.
    @Test(.tags(.edgeCase)) func pinnedFolderCannotBeKept() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, (1...4).map { "Indirme/\($0).jpg" } + ["Indirme/x.crdownload", "Calisma/a.pdf", "Calisma/b.pdf", "Calisma/proj/.git/HEAD"])
        let partial = f.root.appending(path: "Indirme/x.crdownload")
        try FileManager.default.setAttributes([.creationDate: Date(), .modificationDate: Date()], ofItemAtPath: partial.path)
        var plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        for name in ["Indirme", "Calisma"] {
            let folder = plan.item(name)
            let lock = try #require(folder.modeLock)
            #expect(throws: PlanError.folderModeLocked(lock)) {
                try PlanEditor.setFolderMode(&plan, itemID: folder.id, mode: .keep)
            }
        }
        #expect(plan.item("Indirme").modeLock == "İçinde taşınmaması gereken öğe var (Yarım indirme)")
    }

    /// Review C2: a folder that is critical by name keeps its contents critical when distributed.
    @Test(.tags(.edgeCase)) func criticalFolderProtectsItsContents() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Kimlik/scan.jpg", "Kimlik/notlar.txt", "Kimlik/x.dmg"])
        let mock = MockLLMProvider(defaultResult: PlannerFixture.result("Belgeler"))
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: true)
        #expect(plan.item("Kimlik").folderMode == .distribute && plan.item("Kimlik").status == .critical)
        for path in ["Kimlik/scan.jpg", "Kimlik/notlar.txt", "Kimlik/x.dmg"] {
            #expect(plan.item(path: path).critical && plan.item(path: path).approved == false)
        }
        #expect(await mock.requests.allSatisfy { $0.request.contentPreview == nil })
    }

    /// Review I1: the central archive inside the scanned root is never scanned or moved.
    @Test(.tags(.edgeCase)) func archiveInsideRootIsNotScanned() async throws {
        var f = try PlannerFixture(standardFiles: false)
        try tree(f, ["Arsiv/Faturalar/2025-02-10_Fatura_Enerjisa.pdf", "Arsiv/Gorseller/x.jpg", "a.pdf"])
        f.settings.targetMode = .central
        f.settings.archiveRoot = f.root.appending(path: "Arsiv").path
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item("Arsiv").skipReason == "Merkezi arşiv klasörü")
        #expect(plan.items.contains { $0.relativePath.hasPrefix("Arsiv/") } == false)
    }

    /// Review I2: a partial download just below the scan horizon still pins the folders above it.
    @Test(.tags(.edgeCase)) func partialDownloadBelowScanHorizonPinsAncestors() async throws {
        let f = try PlannerFixture(standardFiles: false)
        try tree(f, (1...5).map { "X/Y/Z/\($0).jpg" } + ["X/Y/Z/big.crdownload"])
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        #expect(plan.item(path: "X/Y/Z").skipReason == "İçinde yarım indirme")
        #expect(plan.item("X").folderMode == .distribute && plan.item(path: "X/Y").folderMode == .distribute)
    }

    /// Review I3: folders beyond the depth limit are marked as not listed.
    @Test func unlistedFoldersAreMarked() async throws {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.scanDepth = 1
        try tree(f, (1...5).map { "Album/\($0).jpg" })
        let shallow = try await f.planner(nil).makePlan(root: f.root, useLLM: false, resume: false)
        #expect(shallow.item("Album").listed == false && shallow.item("Album").folderMode == .keep)
        f.settings.scanDepth = 3
        let deep = try await f.planner(nil).makePlan(root: f.root, useLLM: false, resume: false)
        #expect(deep.item("Album").listed)
    }
}
