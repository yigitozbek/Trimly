import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct FolderScannerTests {
    @Test func scansTopLevelOnly() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("a.pdf", in: root)
        try TestFS.file(".hidden", in: root)
        let sub = try TestFS.folder("sub", in: root)
        try TestFS.file("inner.txt", in: sub)
        #expect(try FolderScanner().scan(root: root).map(\.name) == [".hidden", "a.pdf", "sub"])
    }

    @Test func fillsBasicMetadata() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("Rapor.PDF", in: root, contents: "hello", modified: .twoDaysAgo)
        let item = try #require(try FolderScanner().scan(root: root).first)
        #expect(item.sizeBytes == 5 && item.fileExtension == "pdf" && item.kind == .file && item.isLink == false)
        let modified = try #require(item.modifiedAt)
        #expect(abs(modified.timeIntervalSince(.twoDaysAgo)) < 2)
        #expect(item.createdAt != nil)
        #expect(item.url == root.appending(path: "Rapor.PDF"))
    }

    @Test func keepsCompoundExtension() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("yedek.tar.gz", in: root)
        #expect(try FolderScanner().scan(root: root).first?.fileExtension == "tar.gz")
    }

    @Test func folderSampleAndHistogram() throws {
        let root = try TestFS.tempDir()
        let album = try TestFS.folder("Album", in: root)
        for i in 0..<22 { try TestFS.file("p\(i).jpg", in: album) }
        for i in 0..<3 { try TestFS.file("n\(i).txt", in: album) }
        try TestFS.file(".DS_Store", in: album)
        let item = try #require(try FolderScanner().scan(root: root).first)
        #expect(item.kind == .folder && item.folderSampleNames.count == 20)
        #expect(item.folderExtensionHistogram == ["jpg": 22, "txt": 3])
        #expect(item.sizeBytes == nil)
    }

    @Test func detectsPackageAndLink() throws {
        let root = try TestFS.tempDir()
        let app = try TestFS.folder("X.app", in: root)
        try TestFS.folder("Contents", in: app)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "link"), withDestinationURL: app)
        let items = try FolderScanner().scan(root: root)
        #expect(items.first { $0.name == "X.app" }?.kind == .package)
        #expect(items.first { $0.name == "link" }?.isLink == true)
    }

    @Test func rejectsNonDirectory() throws {
        let root = try TestFS.tempDir()
        let file = try TestFS.file("a.txt", in: root)
        #expect(throws: ScanError.notADirectory(file)) {
            try FolderScanner().scan(root: file)
        }
    }
}
