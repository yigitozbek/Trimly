import Foundation

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.malformedResponse
            }
            return (data, http)
        } catch let error as URLError where error.code != .cancelled {
            throw LLMError.unreachable
        }
    }
}
