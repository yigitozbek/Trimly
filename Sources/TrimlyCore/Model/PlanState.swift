import Foundation

public enum PlanState: String, Codable, Sendable {
    case inProgress
    case ready
    case applied
}
