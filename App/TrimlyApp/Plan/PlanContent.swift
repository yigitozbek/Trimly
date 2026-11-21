import AppKit
import SwiftUI

/// "Pending first" layout: items that need a decision on top, ready items collapsed by category, skipped last.
struct PlanContent: View {
    @State private var session: PlanSession
    @State private var isConfirmingApply = false
    @State private var isShowingResult = false
    @State private var isShowingError = false

    init(root: URL, environment: AppEnvironment) {
        _session = State(initialValue: PlanSession(root: root, environment: environment))
    }

    var body: some View {
        List {
            if session.canResume {
                ResumeRow(resume: resume, rescan: rescan)
            }
            if let notice = session.scanNotice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            PendingSection(session: session)
            ReadySection(session: session)
            SkippedSection(session: session)
        }
        .safeAreaInset(edge: .top) {
            if let banner = session.banner {
                BannerView(text: banner)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ProgressFooter(session: session, showResult: showResult)
        }
        .searchable(text: $session.searchText, prompt: "Ada göre ara")
        .navigationTitle(PathFormatting.displayName(session.root))
        .toolbar {
            ToolbarItemGroup {
                Button("Yeniden tara", systemImage: "arrow.clockwise", action: rescan)
                    .disabled(session.isBusy)
                Button("Detaylı incele (\(session.stage2CandidateCount))", systemImage: "sparkle.magnifyingglass", action: runStage2)
                    .disabled(session.stage2Available == false || session.isBusy)
                    .help(session.stage2Available ? "İnceleme ve kritik öğeleri büyük modelle yeniden değerlendirir." : "Ollama ve 2. aşama modeli gerekli; ya da incelenecek öğe yok.")
                Button("Uygula (\(session.approvedCount))", systemImage: "checkmark.circle", action: confirmApply)
                    .disabled(session.approvedCount == 0 || session.isReadOnly || session.isBusy)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .task {
            await session.start()
        }
        .onDisappear(perform: session.cancel)
        .onChange(of: session.phase) { _, phase in
            if case .applied = phase {
                isShowingResult = true
            }
        }
        .onChange(of: session.errorMessage) { _, message in
            isShowingError = message != nil
        }
        .sheet(isPresented: $isConfirmingApply) {
            ApplySheet(summary: session.applySummary, onApply: apply)
        }
        .sheet(isPresented: $isShowingResult) {
            ResultSheet(session: session)
        }
        .alert("Bir sorun oluştu", isPresented: $isShowingError) {
            Button("Tamam", action: session.clearError)
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private func resume() {
        Task { await session.start() }
    }

    private func rescan() {
        Task { await session.rescan() }
    }

    private func runStage2() {
        Task { await session.runStage2() }
    }

    private func confirmApply() {
        isConfirmingApply = true
    }

    private func apply() {
        isConfirmingApply = false
        Task { await session.apply(confirming: session.applySummary) }
    }

    private func showResult() {
        isShowingResult = true
    }
}
