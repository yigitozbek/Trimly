import SwiftUI

struct PlanWindow: View {
    @Binding var root: URL?

    var body: some View {
        Group {
            if let root {
                Text(root.path)
            } else {
                ContentUnavailableView("Klasör bekleniyor", systemImage: "folder")
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .onOpenURL { url in
            guard root == nil, case .organize(let folder)? = try? URLRouter.route(url) else {
                return
            }
            LaunchState.shared.launchedByURL = true
            root = folder
        }
    }
}
