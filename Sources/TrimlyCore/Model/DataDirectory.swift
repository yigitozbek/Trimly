import Foundation

public struct DataDirectory: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// `~/Library/Application Support/Trimly`
    public static var `default`: DataDirectory {
        DataDirectory(root: URL.applicationSupportDirectory.appending(path: "Trimly", directoryHint: .isDirectory))
    }

    public var settingsURL: URL { root.appending(path: "settings.json", directoryHint: .notDirectory) }
    public var plansURL: URL { root.appending(path: "plans", directoryHint: .isDirectory) }
    public var runsURL: URL { root.appending(path: "runs", directoryHint: .isDirectory) }

    public func ensureExists() throws {
        for url in [root, plansURL, runsURL] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
