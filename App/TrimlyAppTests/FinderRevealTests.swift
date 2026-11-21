import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@Suite(.tags(.fileSystem))
struct FinderRevealTests {
    func item(source: URL, target: URL? = nil, name: String = "a.pdf") -> PlanItem {
        PlanItem(
            id: "x", name: name, source: source, kind: .file, fileExtension: "pdf",
            resolvedDate: Date(), target: target, status: .ready,
            sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: Date())
        )
    }

    @Test func revealsExistingURLsOnly() throws {
        let dir = try TestFS.tempDir()
        let a = try TestFS.file("a.pdf", in: dir)
        let missing = dir.appending(path: "gone.pdf")
        #expect(FinderReveal.existing([a, missing]) == [a])
        #expect(FinderReveal.existing([missing]).isEmpty)
    }

    @Test func itemUsesSourceWhenPresent() throws {
        let dir = try TestFS.tempDir()
        let source = try TestFS.file("a.pdf", in: dir)
        #expect(FinderReveal.url(for: item(source: source))?.path == source.path)
    }

    @Test func itemFallsBackToTargetWhenSourceGone() throws {
        let dir = try TestFS.tempDir()
        let source = dir.appending(path: "a.pdf")
        let target = try TestFS.file("moved.pdf", in: try TestFS.tempDir())
        #expect(FinderReveal.url(for: item(source: source, target: target))?.path == target.path)
    }

    @Test func resultURLsPreferDestinationsThenRoot() throws {
        let root = try TestFS.tempDir()
        let dest = try TestFS.file("out.pdf", in: try TestFS.tempDir())
        #expect(FinderReveal.resultURLs(destinations: [dest], root: root) == [dest])
        #expect(FinderReveal.resultURLs(destinations: [root.appending(path: "missing.pdf")], root: root) == [root])
    }
}
