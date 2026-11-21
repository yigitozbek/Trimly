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

    @Test func scanTreeDescendsToDepth() throws {
        let root = try TestFS.tempDir()
        let a = try TestFS.folder("A", in: root)
        let b = try TestFS.folder("B", in: a)
        try TestFS.file("c.txt", in: b)
        try TestFS.file("x.pdf", in: a)
        let deep = try FolderScanner().scanTree(root: root, maxDepth: 3) { _ in true }
        let paths = Dictionary(uniqueKeysWithValues: deep.items.map { ($0.relativePath, $0.depth) })
        #expect(paths == ["A": 0, "A/B": 1, "A/x.pdf": 1, "A/B/c.txt": 2])
        #expect(deep.items.first { $0.relativePath == "A/B/c.txt" }?.parentRelativePath == "A/B")
        #expect(deep.truncated == false)
        let shallow = try FolderScanner().scanTree(root: root, maxDepth: 2) { _ in true }
        #expect(shallow.items.map(\.relativePath).contains("A/B/c.txt") == false)
    }

    @Test func shouldDescendIsHonoured() throws {
        let root = try TestFS.tempDir()
        let project = try TestFS.folder("proj", in: root)
        try TestFS.folder(".git", in: project)
        try TestFS.file("a.txt", in: project)
        let tree = try FolderScanner().scanTree(root: root, maxDepth: 3) { $0.name != "proj" }
        #expect(tree.items.map(\.relativePath) == ["proj"])
    }

    @Test func histogramCountsDescendants() throws {
        let root = try TestFS.tempDir()
        let album = try TestFS.folder("Album", in: root)
        try TestFS.file("a.jpg", in: album)
        let sub = try TestFS.folder("alt", in: album)
        try TestFS.file("b.jpg", in: sub)
        try TestFS.file("c.jpg", in: sub)
        try TestFS.file(".DS_Store", in: sub)
        let tree = try FolderScanner().scanTree(root: root, maxDepth: 3) { _ in true }
        #expect(tree.items.first { $0.relativePath == "Album" }?.folderExtensionHistogram == ["jpg": 3])
    }

    @Test(.tags(.edgeCase)) func stopsDescendingAtLimit() throws {
        let root = try TestFS.tempDir()
        for index in 0..<4 {
            let folder = try TestFS.folder("F\(index)", in: root)
            for file in 0..<2 { try TestFS.file("f\(file).txt", in: folder) }
        }
        let tree = try FolderScanner().scanTree(root: root, maxDepth: 3, limit: 5) { _ in true }
        #expect(tree.items.count == 5 && tree.truncated)
    }

    @Test func topLevelScanUnchanged() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("a.pdf", in: root)
        let sub = try TestFS.folder("sub", in: root)
        try TestFS.file("inner.txt", in: sub)
        let tree = try FolderScanner().scanTree(root: root, maxDepth: 1) { _ in true }
        #expect(try FolderScanner().scan(root: root).map(\.name) == tree.items.map(\.name))
    }

    /// Review I2: a folder cut off by the item limit is not reported as listed.
    @Test(.tags(.edgeCase)) func partiallyListedFolderIsNotDescended() throws {
        let root = try TestFS.tempDir()
        for index in 0..<4 {
            let folder = try TestFS.folder("F\(index)", in: root)
            for file in 0..<2 { try TestFS.file("f\(file).txt", in: folder) }
        }
        let tree = try FolderScanner().scanTree(root: root, maxDepth: 3, limit: 5) { _ in true }
        #expect(tree.truncated && tree.descended.isEmpty)
    }
}
