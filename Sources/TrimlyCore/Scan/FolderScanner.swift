import Foundation
import UniformTypeIdentifiers

/// Lists a folder's items with the metadata later stages need: the top level (`scan`) or a depth-limited tree (`scanTree`).
public struct FolderScanner: Sendable {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isAliasFileKey, .fileSizeKey,
        .creationDateKey, .contentModificationDateKey, .contentTypeKey
    ]
    private static let folderSampleLimit = 20

    public init() {}

    public func scan(root: URL) throws -> [FileItem] {
        try scanTree(root: root, maxDepth: 1) { _ in false }.items
    }

    /// Breadth-first: items with `depth < maxDepth`; descends only into folders `shouldDescend` accepts.
    /// Stops adding items at `limit` (`truncated`). Descended folders get a histogram of all included descendant files.
    public func scanTree(root: URL, maxDepth: Int, limit: Int = 5_000, shouldDescend: (FileItem) -> Bool) throws -> ScanTree {
        guard (try? root.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            throw ScanError.notADirectory(root)
        }
        var items: [FileItem] = []
        var truncated = false
        var descended: Set<String> = []
        var queue: [(url: URL, relative: String?, depth: Int)] = [(root, nil, 0)]
        var next = 0
        scanning: while next < queue.count {
            let (folder, relative, depth) = queue[next]
            next += 1
            // Item URLs are rebuilt from `root` so they share its form: the listing may report `/private/var/...`
            // for a root given as `/var/...`, which would break later source/target path comparisons.
            let names: [String]
            if relative == nil {
                names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
            } else {
                names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
            }
            for name in names {
                guard items.count < limit else {
                    truncated = true
                    break scanning
                }
                let path = relative.map { "\($0)/\(name)" } ?? name
                let item = try item(at: folder.appending(path: name), relativePath: path, depth: depth, parent: relative)
                items.append(item)
                if item.kind == .folder, depth + 1 < maxDepth, shouldDescend(item) {
                    queue.append((item.url, path, depth + 1))
                }
            }
            // Only after the whole listing: a folder cut off by the limit keeps its direct-children histogram.
            if let relative {
                descended.insert(relative)
            }
        }
        return ScanTree(items: withDescendantHistograms(items, descended: descended), truncated: truncated, descended: descended)
    }

    private func withDescendantHistograms(_ items: [FileItem], descended: Set<String>) -> [FileItem] {
        guard descended.isEmpty == false else { return items }
        var counts: [String: [String: Int]] = [:]
        for item in items where item.kind != .folder && item.name.hasPrefix(".") == false {
            let ext = item.fileExtension
            guard ext.isEmpty == false else { continue }
            var ancestor = item.parentRelativePath
            while let folder = ancestor {
                if descended.contains(folder) {
                    counts[folder, default: [:]][ext, default: 0] += 1
                }
                ancestor = folder.contains("/") ? String(folder[..<folder.lastIndex(of: "/")!]) : nil
            }
        }
        return items.map { item in
            guard descended.contains(item.relativePath) else { return item }
            return item.withHistogram(counts[item.relativePath] ?? [:])
        }
    }

    private func item(at url: URL, relativePath: String, depth: Int, parent: String?) throws -> FileItem {
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
            isLink: isLink,
            relativePath: relativePath,
            depth: depth,
            parentRelativePath: parent
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
