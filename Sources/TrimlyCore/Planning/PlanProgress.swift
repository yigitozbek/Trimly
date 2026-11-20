import Foundation

public struct PlanProgress: Sendable {
    public let processed: Int
    public let total: Int
    public let stage: Int

    public init(processed: Int, total: Int, stage: Int) {
        self.processed = processed
        self.total = total
        self.stage = stage
    }
}
