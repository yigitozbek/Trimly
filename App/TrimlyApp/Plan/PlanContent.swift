import AppKit
import SwiftUI
import TrimlyCore

/// "Pending first" layout: items that need a decision on top, ready items collapsed by category, skipped last.
struct PlanContent: View {
    @State private var session: PlanSession
    @State private var selectedItemID: String?
    @State private var isConfirmingApply = false
    @State private var isShowingResult = false
    @State private var isShowingError = false

    init(root: URL, environment: AppEnvironment) {
        _session = State(initialValue: PlanSession(root: root, environment: environment))
    }

    var body: some View {
        List(selection: $selectedItemID) {
            if session.canResume {
                ResumeRow(resume: resume, rescan: rescan)
            }
            if let notice = session.scanNotice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            PendingSection(session: session)
            ReadySection(session: session)
            TrashSection(session: session)
            SkippedSection(session: session)
        }
        .onKeyPress(.space) {
            previewSelection()
            return .handled
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if let banner = session.banner {
                    BannerView(text: banner)
                }
                RecentSkipBanner(session: session)
                    .padding(.horizontal, 12)
                    .padding(.top, session.banner == nil ? 8 : 0)
                    .padding(.bottom, session.recentSkipCount > 0 ? 8 : 0)
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
                Button("Önizle", systemImage: "eye", action: previewSelection)
                    .disabled(selectedPreviewItem == nil)
                    .help("Seçili dosyayı Quick Look ile açar (Space).")
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

    private var selectedPreviewItem: PlanItem? {
        guard let id = selectedItemID else { return nil }
        return session.plan?.items.first { $0.id == id }
    }

    private func previewSelection() {
        guard let item = selectedPreviewItem else { return }
        QuickLookPresenter.shared.present(item: item)
    }
}
