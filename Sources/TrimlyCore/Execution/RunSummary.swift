import Foundation

public struct RunSummary: Sendable {
    public let runID: String
    public let moved: Int
    public let skipped: [SkippedEntry]
    public let failed: [SkippedEntry]
    /// Items that got tags added.
    public let tagged: Int
    /// Items moved to Trash in this run.
    public let trashed: Int

    public init(
        runID: String,
        moved: Int,
        skipped: [SkippedEntry],
        failed: [SkippedEntry],
        tagged: Int = 0,
        trashed: Int = 0
    ) {
        self.runID = runID
        self.moved = moved
        self.skipped = skipped
        self.failed = failed
        self.tagged = tagged
        self.trashed = trashed
    }
}
