import Foundation

public enum UndoError: Error, Equatable {
    case noRuns
    case runNotFound(String)
}
