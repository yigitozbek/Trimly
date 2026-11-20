import Foundation

public enum PlanError: Error, Equatable {
    case notFound(String)
    case itemNotFound(String)
    case unknownCategory(String)
    case alreadyApplied
    case notReady
}
