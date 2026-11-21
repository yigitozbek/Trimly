import Foundation

public struct UndoSummary: Sendable {
    public let runID: String
    public let restored: Int
    public let removedFolders: Int
    public let skipped: [SkippedEntry]
    /// Items whose previous tags were written back.
    public let restoredTags: Int

    public init(runID: String, restored: Int, removedFolders: Int, skipped: [SkippedEntry], restoredTags: Int = 0) {
        self.runID = runID
        self.restored = restored
        self.removedFolders = removedFolders
        self.skipped = skipped
        self.restoredTags = restoredTags
    }
}
