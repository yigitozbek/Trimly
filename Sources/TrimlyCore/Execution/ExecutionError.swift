import Foundation

public enum ExecutionError: Error, Equatable {
    case alreadyApplied
    case notReady
}
