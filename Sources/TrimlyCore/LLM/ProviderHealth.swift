import Foundation

public struct ProviderHealth: Sendable, Equatable {
    public let reachable: Bool
    public let availableModels: [String]

    public init(reachable: Bool, availableModels: [String]) {
        self.reachable = reachable
        self.availableModels = availableModels
    }
}
