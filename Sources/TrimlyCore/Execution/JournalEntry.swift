import Foundation

/// One JSONL line. Operation lines carry `op`; later state changes are separate lines with only `ref` + `state`.
public struct JournalEntry: Codable, Equatable, Sendable {
    public var seq: Int
    public var type: String?
    public var op: JournalOp?
    public var ref: Int?
    public var state: JournalState?
    public var from: String?
    public var to: String?
    public var path: String?
    public var size: Int64?
    public var mtime: Date?
    public var runID: String?
    public var planID: String?
    public var root: String?
    public var at: Date?
    public var message: String?
    /// `tag`: the full tag list written, and the list it replaced.
    public var tags: [String]?
    public var previousTags: [String]?

    public init(
        seq: Int,
        type: String? = nil,
        op: JournalOp? = nil,
        ref: Int? = nil,
        state: JournalState? = nil,
        from: String? = nil,
        to: String? = nil,
        path: String? = nil,
        size: Int64? = nil,
        mtime: Date? = nil,
        runID: String? = nil,
        planID: String? = nil,
        root: String? = nil,
        at: Date? = nil,
        message: String? = nil,
        tags: [String]? = nil,
        previousTags: [String]? = nil
    ) {
        self.seq = seq
        self.type = type
        self.op = op
        self.ref = ref
        self.state = state
        self.from = from
        self.to = to
        self.path = path
        self.size = size
        self.mtime = mtime
        self.runID = runID
        self.planID = planID
        self.root = root
        self.at = at
        self.message = message
        self.tags = tags
        self.previousTags = previousTags
    }

    /// A pure state-change line (`{"seq":3,"ref":2,"state":"done"}`).
    var isStateUpdate: Bool {
        op == nil && type == nil && ref != nil
    }
}
