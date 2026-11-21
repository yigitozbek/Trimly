import Foundation
import TrimlyCore

/// Turkish labels for plan rows.
enum ItemFormatting {
    static func statusLabel(_ item: PlanItem) -> String {
        switch item.status {
        case .critical: "Kritik"
        case .review: item.kind == .folder ? "Klasör" : "İnceleme"
        case .ready: "Hazır"
        case .skipped: "Atlandı"
        }
    }

    /// "sebep · güven 0.60 · karar: kural" — parts that are unknown are left out.
    static func detail(_ item: PlanItem) -> String {
        var parts: [String] = []
        if let reason = item.reason {
            parts.append(reason)
        } else if let reviewReason = item.reviewReason {
            parts.append(reviewLabel(reviewReason))
        } else if let skipReason = item.skipReason {
            parts.append(skipReason)
        }
        if let confidence = item.confidence {
            parts.append("güven \(String(format: "%.2f", confidence))")
        }
        if let decidedBy = item.decidedBy {
            parts.append("karar: \(decisionLabel(decidedBy))")
        }
        return parts.joined(separator: " · ")
    }

    static func reviewLabel(_ reason: ReviewReason) -> String {
        switch reason {
        case .lowConfidence: "düşük güven"
        case .llmError: "LLM hatası"
        case .weakRuleNoLLM: "LLM'siz zayıf kural"
        case .folder: "klasör, elle onay gerekir"
        }
    }

    static func decisionLabel(_ decidedBy: DecidedBy) -> String {
        switch decidedBy {
        case .rule: "kural"
        case .llm1: "LLM"
        case .llm2: "LLM (detaylı)"
        case .manual: "elle"
        }
    }
}
