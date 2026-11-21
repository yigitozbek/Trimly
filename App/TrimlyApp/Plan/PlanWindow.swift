import SwiftUI

/// Scene content for one folder. The folder arrives as the window's value or through a `trimly://` link.
struct PlanWindow: View {
    @Binding var root: URL?
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        Group {
            if let root {
                PlanContent(root: root, environment: environment)
                    .id(root)
            } else {
                ContentUnavailableView("Klasör bekleniyor", systemImage: "folder")
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
        .onOpenURL(perform: open)
    }

    private func open(_ url: URL) {
        guard root == nil, case .organize(let folder)? = try? URLRouter.route(url) else {
            return
        }
        root = folder
        LaunchState.shared.noteURLOpen()
    }
}
