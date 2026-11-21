import SwiftUI

/// Every applied run, newest first, each with Geri Al.
struct HistoryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: RunsModel?

    var body: some View {
        ScrollView {
            if let model {
                RunsList(model: model)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .toolbar {
            Button("Yenile", systemImage: "arrow.clockwise", action: refresh)
        }
        .task(load)
    }

    private func load() async {
        if model == nil {
            model = RunsModel(environment: environment, limit: nil)
        }
        await model?.refresh()
    }

    private func refresh() {
        Task { await model?.refresh() }
    }
}
