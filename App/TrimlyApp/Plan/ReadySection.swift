import SwiftUI

struct ReadySection: View {
    let session: PlanSession

    var body: some View {
        Section("Hazır (\(session.readyGroups.map(\.items.count).reduce(0, +)))") {
            ForEach(session.readyGroups) { group in
                DisclosureGroup {
                    ForEach(group.items) { item in
                        ItemRow(item: item, session: session, isEditable: false)
                    }
                } label: {
                    CategoryGroupHeader(group: group, session: session)
                }
            }
        }
    }
}
