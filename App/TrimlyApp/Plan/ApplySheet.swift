import SwiftUI

/// Final confirmation before anything moves (or tags are added). Critical items approved by hand are listed separately.
struct ApplySheet: View {
    let summary: ApplySummary
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.bold())
            Text(explanation)
                .foregroundStyle(.secondary)
            GroupBox("Kategoriler") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.byCategory) { category in
                        LabeledContent(category.title, value: "\(category.count)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if summary.criticalApproved.isEmpty == false {
                GroupBox("Elle onaylanmış kritik öğeler") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.criticalApproved) { item in
                            Label(item.name, systemImage: "lock.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Uygula", action: onApply)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var title: String {
        summary.isTagOnly
            ? "\(summary.count) öğeye etiket eklenecek"
            : "\(summary.count) öğe taşınacak"
    }

    private var explanation: String {
        if summary.isTagOnly {
            return "Hiçbir dosya taşınmaz; Geri Al eklenen etiketleri kaldırır."
        }
        var text = summary.removesEmptyFolders
            ? "Her taşıma kaydedilir ve Geri Al ile geri alınabilir. Hiçbir dosya üzerine yazılmaz. Boşalan klasörler kaldırılır; Geri Al onları yeniden oluşturur."
            : "Her taşıma kaydedilir ve Geri Al ile geri alınabilir. Hiçbir dosya silinmez veya üzerine yazılmaz."
        if summary.addsCategoryTags {
            text += " Taşınan dosyalara kategori etiketi eklenir."
        }
        return text
    }

    private func cancel() {
        dismiss()
    }
}
