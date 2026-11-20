import Foundation
import Testing
@testable import TrimlyCore

/// Scripted HTTP transport: returns `responses` in order (repeating the last) and records every request.
actor RecordingTransport: HTTPTransport {
    private let responses: [Result<(Int, Data), any Error>]
    private(set) var requests: [URLRequest] = []

    init(responses: [Result<(Int, Data), any Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let index = min(requests.count - 1, responses.count - 1)
        let (status, data) = try responses[index].get()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (data, response)
    }

    /// Parses a recorded request body on the caller's side (`[String: Any]` cannot cross the actor boundary).
    static func bodyJSON(_ request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}
