import Foundation

/// Injected HTTP layer so providers can be tested without live networking.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
