import Foundation

public enum ExecutionError: Error, Equatable {
    case alreadyApplied
    case notReady
    /// Item is not a Trash candidate (or is critical / covered / a folder / already trashed).
    case notTrashCandidate
}
