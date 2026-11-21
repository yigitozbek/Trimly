import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@Suite(.tags(.fileSystem))
struct QuickLookPresenterTests {
    @Test func previewURLNilForMissingOrFolder() throws {
        let dir = try TestFS.tempDir()
        let missing = PlanItem(
            id: "m", name: "gone.pdf", source: dir.appending(path: "gone.pdf"), kind: .file,
            fileExtension: "pdf", resolvedDate: Date(), status: .ready,
            sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: Date())
        )
        #expect(QuickLookPresenter.previewURL(for: missing) == nil)

        let folder = PlanItem(
            id: "f", name: "Album", source: dir, kind: .folder, fileExtension: "",
            resolvedDate: Date(), status: .review, sourceFingerprint: SourceFingerprint(size: nil, modifiedAt: Date())
        )
        #expect(QuickLookPresenter.previewURL(for: folder) == nil)
    }

    @Test func previewURLForExistingFile() throws {
        let dir = try TestFS.tempDir()
        let file = try TestFS.file("a.pdf", in: dir)
        let item = PlanItem(
            id: "a", name: "a.pdf", source: file, kind: .file, fileExtension: "pdf",
            resolvedDate: Date(), status: .ready,
            sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: Date())
        )
        #expect(QuickLookPresenter.previewURL(for: item)?.path == file.path)
    }
}
