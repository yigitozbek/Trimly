import Foundation

public enum PlanError: Error, Equatable {
    case notFound(String)
    case itemNotFound(String)
    case unknownCategory(String)
    case alreadyApplied
    case notReady
    case notAFolder
    /// The folder must stay distributed; the reason is shown to the user.
    case folderModeLocked(String)
    /// The folder's contents were never listed, so they cannot be distributed.
    case folderNotListed
}
