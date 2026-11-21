import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct TrashDetectorTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed

    func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    func plan(files: [(name: String, contents: String, created: Date, modified: Date?)], _ change: (inout Settings) -> Void = { _ in }) async throws -> Plan {
        var f = try PlannerFixture(standardFiles: false)
        f.settings.recentMinutes = 0
        change(&f.settings)
        for file in files {
            let url = try TestFS.file(file.name, in: f.root, contents: file.contents, modified: file.modified ?? file.created, created: file.created)
            _ = url
        }
        return try await f.planner(nil, now: now).makePlan(root: f.root, useLLM: false)
    }

    @Test func oldInstallerIsCandidate() async throws {
        let plan = try await plan(files: [
            ("Setup.dmg", "x", daysAgo(40), nil)
        ])
        #expect(plan.item("Setup.dmg").trashReason == .oldInstaller(days: 30))
        #expect(plan.item("Setup.dmg").approved == false)
    }

    @Test func freshPartialStillSkipped() async throws {
        let plan = try await plan(files: [
            ("a.crdownload", "x", daysAgo(0), nil)
        ])
        #expect(plan.item("a.crdownload").status == .skipped)
        #expect(plan.item("a.crdownload").skipReason == "Yarım indirme")
        #expect(plan.item("a.crdownload").trashReason == nil)
    }

    @Test func stalePartialIsTrashCandidate() async throws {
        let plan = try await plan(files: [
            ("a.crdownload", "x", daysAgo(2), nil)
        ])
        #expect(plan.item("a.crdownload").status != .skipped)
        #expect(plan.item("a.crdownload").trashReason == .stalePartialDownload)
        #expect(plan.item("a.crdownload").approved == false)
    }

    @Test func duplicatePicksOriginalByName() async throws {
        let plan = try await plan(files: [
            ("a.pdf", "same-bytes", daysAgo(5), nil),
            ("a (1).pdf", "same-bytes", daysAgo(5), nil)
        ])
        #expect(plan.item("a.pdf").trashReason == nil)
        #expect(plan.item("a (1).pdf").trashReason == .duplicate(of: "a.pdf"))
    }

    @Test func emptyAndTemp() async throws {
        let plan = try await plan(files: [
            ("empty.txt", "", daysAgo(1), nil),
            ("~$book.docx", "x", daysAgo(1), nil),
            ("scratch.tmp", "x", daysAgo(1), nil)
        ])
        #expect(plan.item("empty.txt").trashReason == .emptyFile)
        #expect(plan.item("~$book.docx").trashReason == .tempFile)
        #expect(plan.item("scratch.tmp").trashReason == .tempFile)
    }

    @Test(.tags(.edgeCase)) func criticalNeverBecomesTrashCandidate() async throws {
        let plan = try await plan(files: [
            ("kimlik.pdf", "TC", daysAgo(40), nil),
            ("old.dmg", "x", daysAgo(40), nil)
        ])
        #expect(plan.item("kimlik.pdf").critical)
        #expect(plan.item("kimlik.pdf").trashReason == nil)
        #expect(plan.item("old.dmg").trashReason == .oldInstaller(days: 30))
    }

    @Test(.tags(.edgeCase)) func coveredItemNeverTrashCandidate() throws {
        let root = try TestFS.tempDir()
        let folderURL = try TestFS.folder("Tatil", in: root)
        let emptyURL = try TestFS.file("empty.txt", in: folderURL, contents: "", modified: daysAgo(2), created: daysAgo(2))
        let folder = PlanItem.stub("Tatil", in: root, category: "photos", kind: .folder, status: .review, reviewReason: .folder, folderMode: .keep)
        let empty = PlanItem.stub("empty.txt", in: root, category: "documents", parent: folder)
        var plan = Plan.stub(root: root, items: [folder, empty])
        CoverageResolver.apply(&plan)
        #expect(plan.item(path: "Tatil/empty.txt").covered)
        let file = FileItem(
            url: emptyURL, name: "empty.txt", fileExtension: "txt", kind: .file, sizeBytes: 0,
            createdAt: daysAgo(2), modifiedAt: daysAgo(2), utTypeIdentifier: nil,
            relativePath: "Tatil/empty.txt", depth: 1, parentRelativePath: "Tatil"
        )
        TrashDetector.apply(&plan, files: [file], settings: plan.settingsSnapshot, now: now)
        #expect(plan.item(path: "Tatil/empty.txt").trashReason == nil)
    }

    @Test func disabledRulesProduceNoCandidates() async throws {
        let plan = try await plan(files: [
            ("Setup.dmg", "x", daysAgo(40), nil),
            ("empty.txt", "", daysAgo(1), nil),
            ("a.tmp", "x", daysAgo(1), nil)
        ]) { settings in
            settings.trashInstallerAgeDays = 30
            settings.trashDuplicates = false
            settings.trashEmptyFiles = false
            settings.trashTempFiles = false
            // Still need installer off — use a huge age threshold
            settings.trashInstallerAgeDays = 10_000
        }
        #expect(plan.items.allSatisfy { $0.trashReason == nil })
    }
}
