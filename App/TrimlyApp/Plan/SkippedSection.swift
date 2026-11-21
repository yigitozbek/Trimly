import SwiftUI

struct SkippedSection: View {
    @Bindable var session: PlanSession

    var body: some View {
        let visible = session.skippedGroups
        let hidden = session.hiddenAlreadyOrganizedCount
        if visible.isEmpty == false || hidden > 0 {
            Section {
                if visible.isEmpty == false {
                    DisclosureGroup("Atlanan (\(visible.map(\.items.count).reduce(0, +)))") {
                        ForEach(visible) { group in
                            DisclosureGroup("\(group.id) (\(group.items.count))") {
                                ForEach(group.items) { item in
                                    Text(item.name)
                                        .foregroundStyle(.secondary)
                                        .tag(item.id)
                                }
                            }
                        }
                    }
                }
                Toggle(isOn: $session.hideAlreadyOrganized) {
                    if hidden > 0 {
                        Text("Zaten düzenli olanları gizle (\(hidden))")
                    } else {
                        Text("Zaten düzenli olanları gizle")
                    }
                }
                .help("Daha önce Trimly ile düzenlenmiş (Zaten düzenli / Zaten etiketli) öğeleri Atlanan listesinden çıkarır.")
            }
        }
    }
}
