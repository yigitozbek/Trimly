import SwiftUI
import TrimlyCore

/// "Dağıt / Bütün tut" for a folder row. Each change is saved at once and recomputes the plan's rows.
struct FolderModePicker: View {
    let item: PlanItem
    let session: PlanSession
    @State private var mode: FolderMode

    init(item: PlanItem, session: PlanSession) {
        self.item = item
        self.session = session
        _mode = State(initialValue: item.folderMode ?? .keep)
    }

    var body: some View {
        Picker("Klasör modu", selection: $mode) {
            Text("Dağıt").tag(FolderMode.distribute)
            Text("Bütün tut").tag(FolderMode.keep)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .disabled(session.isReadOnly || session.isBusy)
        .accessibilityLabel("\(item.name) klasör modu")
        .help("Dağıt: içindekiler tek tek düzenlenir, klasör yerinde kalır. Bütün tut: klasör tek parça taşınır.")
        .onChange(of: mode) { _, newMode in
            guard newMode != item.folderMode else { return }
            session.setFolderMode(newMode, for: item.id)
        }
        .onChange(of: item.folderMode) { _, current in
            mode = current ?? .keep
        }
        .onChange(of: session.revision) {
            // A refused change leaves the item unchanged, so `onChange(of: item.folderMode)` does not fire.
            mode = item.folderMode ?? .keep
        }
    }
}
