import Foundation

public struct RunInfo: Sendable, Equatable, Identifiable {
    public let runID: String
    public let planID: String
    public let root: String
    public let at: Date
    public let moved: Int
    public let undone: Bool
    /// Items that got tags added.
    public let tagged: Int
    /// Items moved to Trash.
    public let trashed: Int
    /// Optional display title (e.g. "Çöp: installer.dmg").
    public let title: String?

    public var id: String { runID }

    public init(
        runID: String,
        planID: String,
        root: String,
        at: Date,
        moved: Int,
        undone: Bool,
        tagged: Int = 0,
        trashed: Int = 0,
        title: String? = nil
    ) {
        self.runID = runID
        self.planID = planID
        self.root = root
        self.at = at
        self.moved = moved
        self.undone = undone
        self.tagged = tagged
        self.trashed = trashed
        self.title = title
    }
}
