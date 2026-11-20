import Foundation

public enum ScanError: Error, Equatable {
    case notADirectory(URL)
}
