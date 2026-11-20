import Foundation

public enum LLMError: Error, Equatable {
    case folderNotAllowed(String)
    case confidenceOutOfRange(Double)
    case malformedResponse
    case http(Int)
    case unreachable
}
