import Foundation

public struct RunSummary: Sendable {
    public let runID: String
    public let moved: Int
    public let skipped: [SkippedEntry]
    public let failed: [SkippedEntry]

    public init(runID: String, moved: Int, skipped: [SkippedEntry], failed: [SkippedEntry]) {
        self.runID = runID
        self.moved = moved
        self.skipped = skipped
        self.failed = failed
    }
}
