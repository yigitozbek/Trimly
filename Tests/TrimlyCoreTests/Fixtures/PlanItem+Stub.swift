import Foundation
@testable import TrimlyCore

extension Date {
    /// 2025-02-10 12:00 local time — midday, so day strings do not depend on the time zone.
    static var feb10Midday: Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10, hour: 12))!
    }
}

extension PlanItem {
    static func stub(
        _ name: String,
        in root: URL,
        category: String? = nil,
        description: String? = nil,
        kind: EntryKind = .file,
        status: ItemStatus = .ready,
        date: Date = .feb10Midday,
        critical: Bool = false,
        approved: Bool = false,
        confidence: Double? = nil,
        reviewReason: ReviewReason? = nil,
        parent: PlanItem? = nil,
        folderMode: FolderMode? = nil,
        skipReason: String? = nil
    ) -> PlanItem {
        let relativePath = parent.map { "\($0.relativePath)/\(name)" } ?? name
        return PlanItem(
            id: String(relativePath.hashValue, radix: 16),
            name: name,
            source: root.appending(path: relativePath),
            kind: kind,
            fileExtension: kind == .folder ? "" : Normalizer.fullExtension(of: name),
            resolvedDate: date,
            categoryID: category,
            description: description,
            confidence: confidence,
            status: status,
            reviewReason: reviewReason,
            skipReason: skipReason,
            critical: critical,
            approved: approved,
            classified: true,
            sourceFingerprint: SourceFingerprint(size: kind == .file ? 1 : nil, modifiedAt: date),
            relativePath: relativePath,
            depth: parent.map { $0.depth + 1 } ?? 0,
            parentID: parent?.id,
            folderMode: folderMode
        )
    }
}

extension Plan {
    static func stub(root: URL, items: [PlanItem], settings: Settings = Settings(), state: PlanState = .ready) -> Plan {
        Plan(id: "test-plan", root: root, createdAt: Date(), state: state, settingsSnapshot: settings, items: items)
    }

    func item(_ name: String) -> PlanItem {
        items.first { $0.name == name }!
    }

    func item(path relativePath: String) -> PlanItem {
        items.first { $0.relativePath == relativePath }!
    }
}
