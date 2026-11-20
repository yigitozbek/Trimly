import Foundation

public struct SpotlightInfo: Sendable, Equatable {
    public var dateAdded: Date?
    public var whereFroms: [String]
    public var title: String?
    public var authors: [String]
    public var contentCreationDate: Date?

    public init(dateAdded: Date? = nil, whereFroms: [String] = [], title: String? = nil, authors: [String] = [], contentCreationDate: Date? = nil) {
        self.dateAdded = dateAdded
        self.whereFroms = whereFroms
        self.title = title
        self.authors = authors
        self.contentCreationDate = contentCreationDate
    }
}
