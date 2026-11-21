import SwiftUI

struct SkippedSection: View {
    let session: PlanSession

    var body: some View {
        if session.skippedGroups.isEmpty == false {
            Section {
                DisclosureGroup("Atlanan (\(session.skippedGroups.map(\.items.count).reduce(0, +)))") {
                    ForEach(session.skippedGroups) { group in
                        DisclosureGroup("\(group.id) (\(group.items.count))") {
                            ForEach(group.items) { item in
                                Text(item.name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
