import SwiftUI

/// Scene content for one folder. The folder arrives as the window's value or through a `trimly://` link;
/// an invalid link shows a warning instead of an empty window.
struct PlanWindow: View {
    @Binding var root: URL?
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var linkError: String?
    @State private var isShowingLinkError = false

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
        .alert("Bağlantı açılamadı", isPresented: $isShowingLinkError) {
            Button("Tamam", action: closeAfterError)
        } message: {
            Text(linkError ?? "")
        }
    }

    private func open(_ url: URL) {
        guard root == nil else { return }
        do {
            guard case .organize(let folder) = try URLRouter.route(url) else { return }
            root = folder
            LaunchState.shared.noteURLOpen()
        } catch let error as URLRouter.RouteError {
            linkError = URLRouter.message(for: error)
            isShowingLinkError = true
        } catch {
            linkError = error.localizedDescription
            isShowingLinkError = true
        }
    }

    private func closeAfterError() {
        linkError = nil
        if root == nil {
            dismiss()
        }
    }
}
