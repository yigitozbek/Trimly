import SwiftUI
import TrimlyCore

/// One plan item. Pending rows can change category, description and approval; ready rows only approval.
/// Local state mirrors the item and is pushed to the session on change (each change is saved to disk).
struct ItemRow: View {
    let item: PlanItem
    let session: PlanSession
    let isEditable: Bool
    @State private var isApproved: Bool
    @State private var categoryID: String
    @State private var descriptionText: String

    init(item: PlanItem, session: PlanSession, isEditable: Bool) {
        self.item = item
        self.session = session
        self.isEditable = isEditable
        _isApproved = State(initialValue: item.approved)
        _categoryID = State(initialValue: item.categoryID ?? "other")
        _descriptionText = State(initialValue: item.description ?? "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("Onayla", isOn: $isApproved)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(session.isReadOnly || session.isBusy)
                .accessibilityLabel("\(item.name) onayı")
            ItemStatusIcon(item: item)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                Text("→ \(targetText)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(ItemFormatting.detail(item))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            if isEditable {
                ItemEditor(item: item, categories: categories, categoryID: $categoryID, descriptionText: $descriptionText, onSubmitDescription: submitDescription)
                    .disabled(session.isBusy)
            }
        }
        .padding(.vertical, 2)
        .onChange(of: isApproved) { _, approved in
            guard approved != item.approved else { return }
            session.setApproved(approved, for: item.id)
        }
        .onChange(of: categoryID) { _, newCategory in
            guard newCategory != item.categoryID else { return }
            session.setCategory(newCategory, for: item.id)
        }
        .onChange(of: item) { _, updated in
            sync(with: updated)
        }
        .onChange(of: session.revision) {
            // After a refused or failed edit the item may be unchanged, so `onChange(of: item)` does not fire.
            sync(with: item)
        }
    }

    private var targetText: String {
        item.target.map { PathFormatting.relative($0, to: session.root) } ?? "—"
    }

    private var categories: [(id: String, title: String)] {
        guard let settings = session.plan?.settingsSnapshot else { return [] }
        return settings.categories.map { ($0.id, $0.folder.value(settings.categoryLanguage)) }
    }

    private func sync(with current: PlanItem) {
        isApproved = current.approved
        categoryID = current.categoryID ?? "other"
        descriptionText = current.description ?? ""
    }

    private func submitDescription() {
        guard descriptionText != (item.description ?? "") else { return }
        session.setDescription(descriptionText, for: item.id)
    }
}
