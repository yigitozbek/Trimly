import ArgumentParser
import Foundation
import TrimlyCore

enum Output {
    /// Runs a command body; any error is printed in Turkish to stderr and turned into exit code 1.
    static func guarding(_ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch let exit as ExitCode {
            throw exit
        } catch {
            printError(message(for: error))
            throw ExitCode.failure
        }
    }

    static func printError(_ text: String) {
        FileHandle.standardError.write(Data("Hata: \(text)\n".utf8))
    }

    static func warn(_ text: String) {
        FileHandle.standardError.write(Data("Uyarı: \(text)\n".utf8))
    }

    @Sendable static func progress(_ progress: PlanProgress) {
        FileHandle.standardError.write(Data("LLM \(progress.processed)/\(progress.total)\n".utf8))
    }

    static func message(for error: any Error) -> String {
        UserMessage.text(for: error)
    }

    // MARK: Plan

    static func printPlan(_ plan: Plan) {
        let visible = plan.items.filter { $0.status != .skipped }.sorted { order($0) < order($1) || (order($0) == order($1) && $0.name < $1.name) }
        for item in visible {
            print(row(item, root: plan.root))
        }
        let skipped = Dictionary(grouping: plan.items.filter { $0.status == .skipped }, by: { $0.skipReason ?? "?" })
        if skipped.isEmpty == false {
            let parts = skipped.sorted { $0.key < $1.key }.map { "\($0.key) ×\($0.value.count)" }
            print("Atlananlar: " + parts.joined(separator: ", "))
        }
    }

    static func row(_ item: PlanItem, root: URL) -> String {
        let mark = item.approved ? "✓" : (item.status == .critical ? "🔒" : "✗")
        let target = item.target.map { relative($0, to: root) } ?? "—"
        let confidence = item.confidence.map { String(format: "%.2f", $0) } ?? "  — "
        let note = item.reason ?? item.reviewReason.map(reviewLabel) ?? ""
        return [mark, pad(statusLabel(item.status), 8), item.id, pad(truncate(item.name, 40), 40), "→", target, confidence, decisionLabel(item.decidedBy), note]
            .joined(separator: "  ")
    }

    static func printStats(_ stats: PlanStats) {
        print("")
        print("Toplam: \(stats.total) · Atlanan: \(stats.skipped) · Kuralla kesin: \(stats.decisiveRule) · LLM'e giden: \(stats.sentToLLM)")
        print("Hazır: \(stats.ready) · İnceleme: \(stats.review) · Kritik: \(stats.critical)")
        if stats.reviewByReason.isEmpty == false {
            let parts = stats.reviewByReason.sorted { $0.key < $1.key }.map { "\(ReviewReason(rawValue: $0.key).map(reviewLabel) ?? $0.key) \($0.value)" }
            print("İnceleme sebepleri: " + parts.joined(separator: ", "))
        }
        if stats.topReviewPatterns.isEmpty == false {
            print("En sık incelemeye düşenler: " + stats.topReviewPatterns.map { "\($0.pattern) ×\($0.count)" }.joined(separator: ", "))
        }
    }

    // MARK: Labels

    static func statusLabel(_ status: ItemStatus) -> String {
        switch status {
        case .ready: "hazır"
        case .review: "inceleme"
        case .critical: "kritik"
        case .skipped: "atlandı"
        }
    }

    static func reviewLabel(_ reason: ReviewReason) -> String {
        switch reason {
        case .lowConfidence: "düşük güven"
        case .llmError: "LLM hatası"
        case .weakRuleNoLLM: "LLM'siz zayıf kural"
        case .folder: "klasör"
        case .mixedFolder: "karışık klasör: dağıt / bütün tut seçin"
        }
    }

    static func decisionLabel(_ decidedBy: DecidedBy?) -> String {
        switch decidedBy {
        case .rule: "kural"
        case .llm1: "llm1"
        case .llm2: "llm2"
        case .manual: "elle"
        case nil: "—"
        }
    }

    static func relative(_ url: URL, to root: URL) -> String {
        let base = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : path
    }

    private static func order(_ item: PlanItem) -> Int {
        switch item.status {
        case .ready: 0
        case .review: 1
        case .critical: 2
        case .skipped: 3
        }
    }

    private static func truncate(_ text: String, _ length: Int) -> String {
        text.count <= length ? text : String(text.prefix(length - 1)) + "…"
    }

    private static func pad(_ text: String, _ length: Int) -> String {
        text.count >= length ? text : text + String(repeating: " ", count: length - text.count)
    }
}
