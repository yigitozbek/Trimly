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
                Text(item.depth > 0 ? item.relativePath : item.name)
                Text(targetText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(ItemFormatting.detail(item))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if item.existingTags.isEmpty == false {
                    Button {
                        SettingsOpener.open(.tags)
                    } label: {
                        Text("Etiketler: " + item.existingTags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Etiket eşlemelerini ayarla")
                }
                if item.folderMode == .keep {
                    coverageText
                }
            }
            Spacer(minLength: 12)
            // No choice for locked folders (they must stay distributed) or unlisted ones (nothing to distribute).
            if isEditable && item.kind == .folder && item.folderMode != nil && item.status != .skipped && item.modeLock == nil && item.listed {
                FolderModePicker(item: item, session: session)
            }
            if isEditable {
                ItemEditor(item: item, categories: categories, categoryID: $categoryID, descriptionText: $descriptionText, onSubmitDescription: submitDescription)
                    .disabled(session.isBusy)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Finder'da göster", systemImage: "folder") {
                FinderReveal.reveal(item: item)
            }
            .disabled(FinderReveal.url(for: item) == nil)
            Button("Etiket eşlemeleri…", systemImage: "tag") {
                SettingsOpener.open(.tags)
            }
            Button("Önizle", systemImage: "eye") {
                QuickLookPresenter.shared.present(item: item)
            }
            .disabled(QuickLookPresenter.previewURL(for: item) == nil)
        }
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

    /// "İçinde N öğe · M kritik dosya": what this folder carries when it moves as one unit.
    @ViewBuilder
    private var coverageText: some View {
        let coverage = session.coverage(of: item)
        if coverage.listed {
            listedCoverageText(coverage)
        } else {
            Text("İçi taranmadı (tarama derinliği veya öğe sınırı); klasör içindekilerle birlikte tek parça taşınır")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func listedCoverageText(_ coverage: FolderCoverage) -> some View {
        let critical = coverage.critical > 0 ? " · \(coverage.critical) kritik dosya; yalnızca tek tek onaylanabilir" : ""
        return Text("İçinde \(coverage.count) öğe\(critical)")
            .font(.caption)
            .foregroundStyle(coverage.critical > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
    }

    private var targetText: String {
        let tag = item.tagsToAdd.first.map { "＋ \($0) etiketi" }
        if let path = item.target.map({ PathFormatting.relative($0, to: session.root) }) {
            if let tag {
                return "→ \(path) · \(tag)"
            }
            return "→ \(path)"
        }
        if let tag {
            return tag
        }
        return "→ —"
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
