import Foundation

enum TestFS {
    /// Unique temporary directory in canonical `realpath` form (`/private/var/...`). `resolvingSymlinksInPath()`
    /// is not used because on macOS it maps `/private/var` back to `/var`.
    static func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "TrimlyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        guard let resolved = realpath(url.path, nil) else {
            return url
        }
        defer { free(resolved) }
        return URL(filePath: String(cString: resolved), directoryHint: .isDirectory)
    }

    @discardableResult
    static func file(
        _ name: String,
        in dir: URL,
        contents: String = "x",
        modified: Date = .twoDaysAgo,
        created: Date? = .twoDaysAgo
    ) throws -> URL {
        let url = dir.appending(path: name, directoryHint: .notDirectory)
        try Data(contents.utf8).write(to: url)
        var attributes: [FileAttributeKey: Any] = [.modificationDate: modified]
        if let created {
            attributes[.creationDate] = created
        }
        try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    /// Sets the Finder tags of a file or folder (replacing any it had). `NSURL`: the `URLResourceValues.tagNames`
    /// setter needs macOS 26.
    static func setTags(_ tags: [String], on url: URL) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }

    static func folder(_ name: String, in dir: URL) throws -> URL {
        let url = dir.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension Date {
    static var twoDaysAgo: Date { Date(timeIntervalSinceNow: -2 * 86_400) }
}
