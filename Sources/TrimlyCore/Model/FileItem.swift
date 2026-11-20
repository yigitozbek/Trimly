import Foundation

public struct FileItem: Codable, Equatable, Sendable {
    public let url: URL
    public let name: String
    public let fileExtension: String
    public let kind: EntryKind
    public let sizeBytes: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let utTypeIdentifier: String?
    public let spotlightDateAdded: Date?
    public let spotlightWhereFroms: [String]
    public let spotlightTitle: String?
    public let spotlightAuthors: [String]
    public let spotlightContentCreationDate: Date?
    public let folderSampleNames: [String]
    public let folderExtensionHistogram: [String: Int]
    public let isLink: Bool

    public init(
        url: URL,
        name: String,
        fileExtension: String,
        kind: EntryKind,
        sizeBytes: Int64?,
        createdAt: Date?,
        modifiedAt: Date?,
        utTypeIdentifier: String?,
        spotlightDateAdded: Date? = nil,
        spotlightWhereFroms: [String] = [],
        spotlightTitle: String? = nil,
        spotlightAuthors: [String] = [],
        spotlightContentCreationDate: Date? = nil,
        folderSampleNames: [String] = [],
        folderExtensionHistogram: [String: Int] = [:],
        isLink: Bool = false
    ) {
        self.url = url
        self.name = name
        self.fileExtension = fileExtension
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.utTypeIdentifier = utTypeIdentifier
        self.spotlightDateAdded = spotlightDateAdded
        self.spotlightWhereFroms = spotlightWhereFroms
        self.spotlightTitle = spotlightTitle
        self.spotlightAuthors = spotlightAuthors
        self.spotlightContentCreationDate = spotlightContentCreationDate
        self.folderSampleNames = folderSampleNames
        self.folderExtensionHistogram = folderExtensionHistogram
        self.isLink = isLink
    }
}
