import Foundation

/// Computes destination folders and reserves conflict-free names (case-insensitive, like APFS).
/// Names already on disk always count as taken, even if their owner moves in the same plan: no move chains or swaps.
public struct TargetResolver {
    private let root: URL
    private let settings: Settings
    private var diskNames: [String: Set<String>] = [:]
    private var reserved: [String: Set<String>] = [:]

    public init(root: URL, settings: Settings) {
        self.root = root
        self.settings = settings
    }

    public func folderURL(categoryFolder: String, date: Date) -> URL {
        let base = switch settings.targetMode {
        // `tagOnly` never asks for a target; the root keeps the resolver total.
        case .inPlace, .tagOnly: root
        case .central: URL(filePath: (settings.archiveRoot as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        }
        var folder = base.appending(path: categoryFolder, directoryHint: .isDirectory)
        if settings.yearSubfolders {
            folder.append(path: String(Calendar.current.component(.year, from: date)), directoryHint: .isDirectory)
        }
        return folder
    }

    /// Returns `source` itself when it already sits at the candidate path; otherwise the first free `name`, `name_2`, `name_3`…
    public mutating func reserve(fileName: String, in folder: URL, source: URL) -> URL {
        let candidate = folder.appending(path: fileName)
        if Self.samePath(candidate, source) {
            return source
        }
        let key = folder.standardizedFileURL.path
        if diskNames[key] == nil {
            // A folder that does not exist yet has no names on disk; only this plan's reservations apply.
            let names = (try? FileManager.default.contentsOfDirectory(atPath: key)) ?? []
            diskNames[key] = Set(names.map { $0.lowercased() })
        }
        let taken = diskNames[key, default: []].union(reserved[key, default: []])

        let ext = Normalizer.fullExtension(of: fileName)
        let stem = ext.isEmpty ? fileName : String(fileName.dropLast(ext.count + 1))
        let extensionPart = ext.isEmpty ? "" : String(fileName.suffix(ext.count + 1))
        var name = fileName
        var counter = 2
        while taken.contains(name.lowercased()) {
            name = "\(stem)_\(counter)\(extensionPart)"
            counter += 1
        }
        reserved[key, default: []].insert(name.lowercased())
        return folder.appending(path: name)
    }

    static func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path.lowercased() == rhs.standardizedFileURL.path.lowercased()
    }
}
