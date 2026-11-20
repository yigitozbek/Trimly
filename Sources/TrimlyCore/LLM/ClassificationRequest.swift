import Foundation

/// Everything the LLM may see about one item. `contentPreview` is always `nil` for critical items.
public struct ClassificationRequest: Sendable, Equatable {
    public var name: String
    public var fileExtension: String
    public var kind: EntryKind
    public var sizeBytes: Int64?
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var utType: String?
    public var sourceHost: String?
    public var spotlightTitle: String?
    public var spotlightAuthors: [String]
    public var ruleHintCategoryFolder: String?
    public var folderSampleNames: [String]
    public var contentPreview: String?
    public var allowedFolders: [String]

    public init(
        name: String,
        fileExtension: String,
        kind: EntryKind,
        sizeBytes: Int64?,
        createdAt: Date?,
        modifiedAt: Date?,
        utType: String?,
        sourceHost: String?,
        spotlightTitle: String?,
        spotlightAuthors: [String],
        ruleHintCategoryFolder: String?,
        folderSampleNames: [String],
        contentPreview: String?,
        allowedFolders: [String]
    ) {
        self.name = name
        self.fileExtension = fileExtension
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.utType = utType
        self.sourceHost = sourceHost
        self.spotlightTitle = spotlightTitle
        self.spotlightAuthors = spotlightAuthors
        self.ruleHintCategoryFolder = ruleHintCategoryFolder
        self.folderSampleNames = folderSampleNames
        self.contentPreview = contentPreview
        self.allowedFolders = allowedFolders
    }

    /// `host + path` of the first download URL; query and fragment (often tokens) are dropped.
    public static func sourceHost(from whereFroms: [String]) -> String? {
        for string in whereFroms {
            if let components = URLComponents(string: string), let host = components.host, host.isEmpty == false {
                return host + components.path
            }
        }
        return nil
    }
}
