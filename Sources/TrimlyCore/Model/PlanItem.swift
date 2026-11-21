import Foundation

public struct PlanItem: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let source: URL
    public let kind: EntryKind
    public let fileExtension: String
    public let resolvedDate: Date
    public var categoryID: String?
    public var description: String?
    public var target: URL?
    public var confidence: Double?
    public var reason: String?
    public var decidedBy: DecidedBy?
    public var status: ItemStatus
    public var reviewReason: ReviewReason?
    public var skipReason: String?
    public var critical: Bool
    public var approved: Bool
    public var classified: Bool
    public let sourceFingerprint: SourceFingerprint
    public let relativePath: String
    public let depth: Int
    public let parentID: String?
    /// Folders only: `keep` moves the folder as a unit, `distribute` plans its contents individually.
    public var folderMode: FolderMode?
    /// Inside a `keep` ancestor: travels with that folder, never approved or targeted on its own.
    public var covered: Bool
    /// Folders only: why the folder must stay `distribute` (it never moves as one unit), e.g. a Trimly category
    /// folder or a partial download inside. Stored so no later edit can switch it to `keep`.
    public let modeLock: String?
    /// Folders only: the scan listed its contents (false beyond the depth limit or the item limit).
    public let listed: Bool

    public init(
        id: String,
        name: String,
        source: URL,
        kind: EntryKind,
        fileExtension: String,
        resolvedDate: Date,
        categoryID: String? = nil,
        description: String? = nil,
        target: URL? = nil,
        confidence: Double? = nil,
        reason: String? = nil,
        decidedBy: DecidedBy? = nil,
        status: ItemStatus,
        reviewReason: ReviewReason? = nil,
        skipReason: String? = nil,
        critical: Bool = false,
        approved: Bool = false,
        classified: Bool = false,
        sourceFingerprint: SourceFingerprint,
        relativePath: String? = nil,
        depth: Int = 0,
        parentID: String? = nil,
        folderMode: FolderMode? = nil,
        covered: Bool = false,
        modeLock: String? = nil,
        listed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.kind = kind
        self.fileExtension = fileExtension
        self.resolvedDate = resolvedDate
        self.categoryID = categoryID
        self.description = description
        self.target = target
        self.confidence = confidence
        self.reason = reason
        self.decidedBy = decidedBy
        self.status = status
        self.reviewReason = reviewReason
        self.skipReason = skipReason
        self.critical = critical
        self.approved = approved
        self.classified = classified
        self.sourceFingerprint = sourceFingerprint
        self.relativePath = relativePath ?? name
        self.depth = depth
        self.parentID = parentID
        self.folderMode = folderMode
        self.covered = covered
        self.modeLock = modeLock
        self.listed = listed
    }

    /// Plans written before nested scanning lack the tree fields; they decode as top-level items.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        source = try c.decode(URL.self, forKey: .source)
        kind = try c.decode(EntryKind.self, forKey: .kind)
        fileExtension = try c.decode(String.self, forKey: .fileExtension)
        resolvedDate = try c.decode(Date.self, forKey: .resolvedDate)
        categoryID = try c.decodeIfPresent(String.self, forKey: .categoryID)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        target = try c.decodeIfPresent(URL.self, forKey: .target)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        decidedBy = try c.decodeIfPresent(DecidedBy.self, forKey: .decidedBy)
        status = try c.decode(ItemStatus.self, forKey: .status)
        reviewReason = try c.decodeIfPresent(ReviewReason.self, forKey: .reviewReason)
        skipReason = try c.decodeIfPresent(String.self, forKey: .skipReason)
        critical = try c.decode(Bool.self, forKey: .critical)
        approved = try c.decode(Bool.self, forKey: .approved)
        classified = try c.decode(Bool.self, forKey: .classified)
        sourceFingerprint = try c.decode(SourceFingerprint.self, forKey: .sourceFingerprint)
        relativePath = try c.decodeIfPresent(String.self, forKey: .relativePath) ?? name
        depth = try c.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID)
        folderMode = try c.decodeIfPresent(FolderMode.self, forKey: .folderMode)
        covered = try c.decodeIfPresent(Bool.self, forKey: .covered) ?? false
        modeLock = try c.decodeIfPresent(String.self, forKey: .modeLock)
        listed = try c.decodeIfPresent(Bool.self, forKey: .listed) ?? false
    }
}
