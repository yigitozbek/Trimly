import Foundation

public struct PlanStats: Codable, Equatable, Sendable {
    public let total: Int
    public let skipped: Int
    public let decisiveRule: Int
    public let sentToLLM: Int
    public let ready: Int
    public let review: Int
    public let critical: Int
    public let reviewByReason: [String: Int]
    public let topReviewPatterns: [PatternCount]

    public init(plan: Plan) {
        let items = plan.items
        func count(_ predicate: (PlanItem) -> Bool) -> Int { items.filter(predicate).count }
        let reviewItems = items.filter { $0.status == .review }

        total = items.count
        skipped = count { $0.status == .skipped }
        decisiveRule = count { $0.decidedBy == .rule && $0.status != .review }
        sentToLLM = count { $0.decidedBy == .llm1 || $0.decidedBy == .llm2 || $0.reviewReason == .llmError }
        ready = count { $0.status == .ready }
        review = reviewItems.count
        critical = count { $0.status == .critical }
        reviewByReason = reviewItems.reduce(into: [:]) { counts, item in
            counts[item.reviewReason?.rawValue ?? "unknown", default: 0] += 1
        }
        let patterns = reviewItems.reduce(into: [String: Int]()) { counts, item in
            let pattern = item.kind == .folder ? "klasör" : (item.fileExtension.isEmpty ? "(uzantısız)" : "." + item.fileExtension)
            counts[pattern, default: 0] += 1
        }
        topReviewPatterns = patterns
            .map { PatternCount(pattern: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.pattern) > ($1.count, $0.pattern) }
            .prefix(10)
            .map { $0 }
    }
}
