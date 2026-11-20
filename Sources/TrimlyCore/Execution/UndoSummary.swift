import Foundation

public struct UndoSummary: Sendable {
    public let runID: String
    public let restored: Int
    public let removedFolders: Int
    public let skipped: [SkippedEntry]

    public init(runID: String, restored: Int, removedFolders: Int, skipped: [SkippedEntry]) {
        self.runID = runID
        self.restored = restored
        self.removedFolders = removedFolders
        self.skipped = skipped
    }
}
