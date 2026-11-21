import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

struct ItemFormattingTests {
    func item(status: ItemStatus, kind: EntryKind = .file, reason: String? = nil, reviewReason: ReviewReason? = nil, confidence: Double? = nil, decidedBy: DecidedBy? = nil) -> PlanItem {
        PlanItem(id: "x", name: "a.pdf", source: URL(filePath: "/tmp/a.pdf"), kind: kind, fileExtension: "pdf", resolvedDate: Date(),
                 confidence: confidence, reason: reason, decidedBy: decidedBy, status: status, reviewReason: reviewReason,
                 critical: status == .critical, sourceFingerprint: SourceFingerprint(size: 1, modifiedAt: Date()))
    }

    @Test func statusLabels() {
        #expect(ItemFormatting.statusLabel(item(status: .critical)) == "Kritik")
        #expect(ItemFormatting.statusLabel(item(status: .review, kind: .folder)) == "Klasör")
        #expect(ItemFormatting.statusLabel(item(status: .review)) == "İnceleme")
        #expect(ItemFormatting.statusLabel(item(status: .ready)) == "Hazır")
    }

    @Test func detailPrefersReasonThenReviewReason() {
        #expect(ItemFormatting.detail(item(status: .review, reason: "Fatura no", confidence: 0.91, decidedBy: .llm1)) == "Fatura no · güven 0.91 · karar: LLM")
        #expect(ItemFormatting.detail(item(status: .review, reviewReason: .weakRuleNoLLM, confidence: 0.6, decidedBy: .rule)) == "LLM'siz zayıf kural · güven 0.60 · karar: kural")
        #expect(ItemFormatting.detail(item(status: .ready, decidedBy: .manual)) == "karar: elle")
    }
}
