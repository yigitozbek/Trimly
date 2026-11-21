import SwiftUI

/// Final confirmation before anything moves. Critical items approved by hand are listed separately.
struct ApplySheet: View {
    let summary: ApplySummary
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(summary.count) öğe taşınacak")
                .font(.title2.bold())
            Text("Her taşıma kaydedilir ve Geri Al ile geri alınabilir. Hiçbir dosya silinmez veya üzerine yazılmaz.")
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

    private func cancel() {
        dismiss()
    }
}
