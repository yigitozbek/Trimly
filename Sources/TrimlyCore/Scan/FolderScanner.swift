import Foundation
import UniformTypeIdentifiers

/// Lists the top level of a folder (never recursive) with the metadata later stages need.
public struct FolderScanner: Sendable {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isAliasFileKey, .fileSizeKey,
        .creationDateKey, .contentModificationDateKey, .contentTypeKey
    ]
    private static let folderSampleLimit = 20

    public init() {}

    public func scan(root: URL) throws -> [FileItem] {
        guard (try? root.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            throw ScanError.notADirectory(root)
        }
        // Item URLs are rebuilt from `root` so they share its form: the listing may report `/private/var/...`
        // for a root given as `/var/...`, which would break later source/target path comparisons.
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        return try names.sorted().map { try item(at: root.appending(path: $0)) }
    }

    private func item(at url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: Self.keys)
        let name = url.lastPathComponent
        let isLink = values.isSymbolicLink == true || values.isAliasFile == true
        let kind: EntryKind = if values.isPackage == true {
            .package
        } else if values.isDirectory == true && isLink == false {
            .folder
        } else {
            .file
        }
        let children = kind == .folder ? visibleChildren(of: url) : []
        let spotlight = MetadataReader.spotlight(for: url)

        return FileItem(
            url: url,
            name: name,
            fileExtension: Normalizer.fullExtension(of: name),
            kind: kind,
            sizeBytes: kind == .file ? values.fileSize.map(Int64.init) : nil,
            createdAt: values.creationDate,
            modifiedAt: values.contentModificationDate,
            utTypeIdentifier: values.contentType?.identifier,
            spotlightDateAdded: spotlight.dateAdded,
            spotlightWhereFroms: spotlight.whereFroms,
            spotlightTitle: spotlight.title,
            spotlightAuthors: spotlight.authors,
            spotlightContentCreationDate: spotlight.contentCreationDate,
            folderSampleNames: Array(children.prefix(Self.folderSampleLimit)),
            folderExtensionHistogram: histogram(of: children),
            isLink: isLink
        )
    }

    private func visibleChildren(of url: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.filter { $0.hasPrefix(".") == false }.sorted()
    }

    private func histogram(of names: [String]) -> [String: Int] {
        names.reduce(into: [:]) { counts, name in
            let ext = Normalizer.fullExtension(of: name)
            if ext.isEmpty == false {
                counts[ext, default: 0] += 1
            }
        }
    }
}
