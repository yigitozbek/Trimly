import Foundation
import Testing
@testable import TrimlyCore

struct TargetResolverTests {
    @Test func inPlaceAndYearFolders() {
        let root = URL(filePath: "/tmp/r")
        #expect(TargetResolver(root: root, settings: Settings()).folderURL(categoryFolder: "Faturalar", date: .now).path == "/tmp/r/Faturalar")
        var settings = Settings()
        settings.yearSubfolders = true
        #expect(TargetResolver(root: root, settings: settings).folderURL(categoryFolder: "Faturalar", date: .feb10Midday).path == "/tmp/r/Faturalar/2025")
    }

    @Test func centralExpandsTilde() {
        var settings = Settings()
        settings.targetMode = .central
        let expected = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents/Arsiv/Faturalar").path
        #expect(TargetResolver(root: URL(filePath: "/tmp/r"), settings: settings).folderURL(categoryFolder: "Faturalar", date: .now).path == expected)
    }

    @Test(.tags(.fileSystem)) func suffixesOnDiskConflictCaseInsensitive() throws {
        let root = try TestFS.tempDir()
        let folder = try TestFS.folder("Faturalar", in: root)
        try TestFS.file("A.pdf", in: folder)
        var resolver = TargetResolver(root: root, settings: Settings())
        #expect(resolver.reserve(fileName: "a.pdf", in: folder, source: root.appending(path: "x.pdf")).lastPathComponent == "a_2.pdf")
    }

    @Test func suffixesWithinPlanEvenIfFolderDoesNotExistYet() throws {
        let root = try TestFS.tempDir()
        let folder = root.appending(path: "Faturalar")
        var resolver = TargetResolver(root: root, settings: Settings())
        let source = root.appending(path: "s")
        let names = [
            resolver.reserve(fileName: "x.pdf", in: folder, source: source),
            resolver.reserve(fileName: "x.pdf", in: folder, source: source),
            resolver.reserve(fileName: "X.PDF", in: folder, source: source)
        ].map(\.lastPathComponent)
        #expect(names == ["x.pdf", "x_2.pdf", "X_3.PDF"])
    }

    @Test(.tags(.edgeCase)) func compoundExtensionSuffix() throws {
        let root = try TestFS.tempDir()
        var resolver = TargetResolver(root: root, settings: Settings())
        let folder = root.appending(path: "Arsivler")
        let source = root.appending(path: "s")
        let names = [resolver.reserve(fileName: "y.tar.gz", in: folder, source: source), resolver.reserve(fileName: "y.tar.gz", in: folder, source: source)].map(\.lastPathComponent)
        #expect(names == ["y.tar.gz", "y_2.tar.gz"])
    }

    @Test(.tags(.fileSystem)) func diskNameStaysOccupiedEvenIfOwnerIsAlsoInPlan() throws {
        let archive = try TestFS.tempDir()
        let invoices = try TestFS.folder("Faturalar", in: archive)
        try TestFS.file("a.pdf", in: invoices)
        let b = try TestFS.file("b.pdf", in: invoices)
        var settings = Settings()
        settings.targetMode = .central
        settings.archiveRoot = archive.path
        var resolver = TargetResolver(root: invoices, settings: settings)
        #expect(resolver.reserve(fileName: "a.pdf", in: invoices, source: b).lastPathComponent == "a_2.pdf")
    }

    @Test(.tags(.fileSystem)) func sameAsSourceReturnsSource() throws {
        let root = try TestFS.tempDir()
        let folder = try TestFS.folder("Faturalar", in: root)
        let source = try TestFS.file("x.pdf", in: folder)
        var resolver = TargetResolver(root: root, settings: Settings())
        #expect(resolver.reserve(fileName: "x.pdf", in: folder, source: source) == source)
    }

    @Test func assignerIsDeterministicAndSkipsSkipped() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [
            .stub("b.pdf", in: root, category: "invoices", description: "Enerjisa-Ocak"),
            .stub("a.pdf", in: root, category: "invoices", description: "Enerjisa-Ocak"),
            .stub("c.pdf", in: root, category: "invoices", status: .skipped),
            .stub("d.pdf", in: root)
        ])
        TargetAssigner.assign(&plan)
        #expect(plan.item("a.pdf").target?.path == root.appending(path: "Faturalar/2025-02-10_Fatura_Enerjisa-Ocak.pdf").path)
        #expect(plan.item("b.pdf").target?.lastPathComponent == "2025-02-10_Fatura_Enerjisa-Ocak_2.pdf")
        #expect(plan.item("c.pdf").target == nil)
        #expect(plan.item("d.pdf").target == nil)
    }

    @Test func assignerUsesFolderNameForFolders() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [.stub("Tatil Fotoğrafları", in: root, category: "photos", kind: .folder, status: .review)])
        TargetAssigner.assign(&plan)
        #expect(plan.item("Tatil Fotoğrafları").target?.path == root.appending(path: "Fotograflar/Tatil-Fotograflari").path)
    }

    @Test func assignerFallsBackToDefaultDescription() throws {
        let root = try TestFS.tempDir()
        var plan = Plan.stub(root: root, items: [.stub("x.png", in: root, category: "images")])
        TargetAssigner.assign(&plan)
        #expect(plan.item("x.png").target?.lastPathComponent == "2025-02-10_Gorsel_Dosya.png")
    }
}
