import Foundation

public struct RunInfo: Sendable, Equatable, Identifiable {
    public let runID: String
    public let planID: String
    public let root: String
    public let at: Date
    public let moved: Int
    public let undone: Bool

    public var id: String { runID }

    public init(runID: String, planID: String, root: String, at: Date, moved: Int, undone: Bool) {
        self.runID = runID
        self.planID = planID
        self.root = root
        self.at = at
        self.moved = moved
        self.undone = undone
    }
}
