import SwiftUI

struct TrashSection: View {
    let session: PlanSession

    var body: some View {
        let items = session.trashSectionItems
        if items.isEmpty == false {
            Section("Çöp adayları (\(items.count))") {
                ForEach(items) { item in
                    TrashRow(item: item, session: session)
                }
            }
        }
    }
}
