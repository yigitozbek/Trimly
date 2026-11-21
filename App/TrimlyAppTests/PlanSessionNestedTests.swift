import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct PlanSessionNestedTests {
    func fixture(_ files: [String]) throws -> AppFixture {
        let f = try AppFixture.empty()
        for path in files {
            let url = f.root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TestFS.file(url.lastPathComponent, in: url.deletingLastPathComponent(), contents: path.hasSuffix("kimlik.pdf") ? "TC kimlik no 12345678901" : "x")
        }
        return f
    }

    func started(_ f: AppFixture) async -> PlanSession {
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        return session
    }

    @Test func mixedFolderItemsAreGroupedUnderTheirFolder() async throws {
        let f = try fixture(["notlar.txt", "Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/c.dmg"])
        let session = await started(f)
        #expect(session.pendingGroups.map(\.title) == ["Üst seviye", "Rastgele"])
        let group = try #require(session.pendingGroups.last)
        #expect(group.folder?.name == "Rastgele" && group.items.map(\.relativePath).contains("Rastgele/a.pdf"))
        #expect(session.pendingItems.contains { $0.name == "Rastgele" } == false)
    }

    @Test func folderModeSwitchMovesRowsBetweenSections() async throws {
        let f = try fixture(["notlar.txt", "Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/c.dmg"])
        let session = await started(f)
        let folder = try f.item("Rastgele", in: session.plan)
        session.setFolderMode(.keep, for: folder.id)
        #expect(session.pendingGroups.map(\.title) == ["Üst seviye"])
        #expect(session.pendingItems.map(\.name).contains("Rastgele"))
        let readyPaths = session.readyGroups.flatMap(\.items).map(\.relativePath)
        #expect(readyPaths.contains { $0.hasPrefix("Rastgele/") } == false)
        #expect(session.pendingItems.contains { $0.relativePath.hasPrefix("Rastgele/") } == false)

        session.setFolderMode(.distribute, for: folder.id)
        #expect(session.pendingGroups.map(\.title).contains("Rastgele"))
    }

    @Test func coveredItemsAreNotSelectable() async throws {
        let f = try fixture((1...5).map { "Tatil/\($0).jpg" } + ["Tatil/kimlik.pdf"])
        let session = await started(f)
        let folder = try f.item("Tatil", in: session.plan)
        #expect(folder.folderMode == .keep)
        #expect(session.coverage(of: folder) == FolderCoverage(count: 6, critical: 1, listed: true))
        session.setPendingApproved(true)
        #expect(try f.item("Tatil", in: session.plan).approved == false)
        #expect(session.readyGroups.flatMap(\.items).isEmpty)
    }

    @Test(.tags(.edgeCase)) func truncatedScanShowsNotice() async throws {
        let f = try fixture(["a.pdf"])
        let store = PlanStore(directory: f.data)
        var plan = try await Planner(settings: f.environment().loadSettings(), store: store, provider: nil).makePlan(root: f.root, useLLM: false)
        #expect(await started(f).scanNotice == nil)
        plan.truncated = true
        try store.save(plan)
        #expect(await started(f).scanNotice == "5.000 öğe sınırına ulaşıldı; daha derindeki öğeler taranmadı.")
    }

    @Test func stage2CountSkipsMixedFolders() async throws {
        let f = try fixture(["notlar.txt", "Rastgele/a.pdf", "Rastgele/b.jpg", "Rastgele/c.dmg"])
        let session = await started(f)
        // notlar.txt and Rastgele/a.pdf; the mixed folder itself never gets a second opinion.
        #expect(session.stage2CandidateCount == 2)
    }

    @Test func applySummaryTellsWhenEmptiedFoldersAreRemoved() async throws {
        let f = try fixture(["Rastgele/a.pdf", "Rastgele/b.jpg"])
        #expect(await started(f).applySummary.removesEmptyFolders == false)
        // Changed settings make the saved plan non-reusable, so the next window plans afresh.
        try f.writeSettings { $0.removeEmptyFolders = true }
        #expect(await started(f).applySummary.removesEmptyFolders)
    }

    /// Review I3: beyond the depth limit the row must not claim the folder is empty.
    @Test func unlistedKeptFolderSaysContentsWereNotScanned() async throws {
        let f = try fixture((1...5).map { "Album/\($0).jpg" })
        try f.writeSettings { $0.scanDepth = 1 }
        let session = await started(f)
        let folder = try f.item("Album", in: session.plan)
        #expect(session.coverage(of: folder).listed == false)
    }
}
