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
        sourceFingerprint: SourceFingerprint
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
    }
}
