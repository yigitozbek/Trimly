# Trimly Faz 2 — SwiftUI Uygulaması Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `TrimlyCore` üstünde native Mac uygulaması: açılış penceresi, "karar bekleyenler önde" plan penceresi, uygula/geri al, geçmiş, ayarlar (seçmeli adlandırma), `trimly://organize` URL şeması, Dock menüsü; artı uygulama+CLI birlikteliği için çekirdek düzeltmeleri.

**Architecture:** XcodeGen ile üretilen `App/Trimly.xcodeproj` (repoya girmez): `TrimlyApp` (SwiftUI, sandbox'sız) + `TrimlyAppTests` (Swift Testing, app-hosted), yerel paket `..` → `TrimlyCore`. İş mantığı `@MainActor @Observable` view model'lerde; view'lar yalnızca gösterir. Ağır işler çekirdekte `@concurrent`.

**Tech Stack:** Swift 6.4 / Xcode 27.2, SwiftUI (macOS 14+), XcodeGen 2.45.3 (`/opt/homebrew/bin/xcodegen`), Swift Testing, TrimlyCore.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-phase2-app-design.md` (üst: `2026-11-21-trimly-design.md`)

## Global Constraints

- Deployment target macOS 14.0; Swift 6 strict concurrency; bundle id `app.trimly.Trimly`; `PRODUCT_NAME: Trimly`, `PRODUCT_MODULE_NAME: TrimlyApp`; team `UBF7FMWA6S`, otomatik imzalama; `ENABLE_APP_SANDBOX: NO`; Info.plist'te `CFBundleURLTypes` → şema `trimly`.
- `App/*.xcodeproj` `.gitignore`'da; üretim: `cd App && xcodegen generate`.
- Uygulama yalnızca `TrimlyCore` + sistem framework'leri kullanır; yeni dış bağımlılık yok.
- Proje skill'leri: `swiftui-pro` (her tür kendi dosyasında, UIKit yok, `foregroundStyle`, simge düğmelerinde metin etiketi / VoiceOver, view'da iş mantığı yok), `swift-concurrency-pro` (`@unchecked Sendable`/`nonisolated(unsafe)` yok, yapılandırılmış eşzamanlılık), `swift-testing-pro` (struct suite, `!` yok, belirli hata, parametreli test). View'lar test edilmez; view model'ler edilir.
- Arayüz metinleri Türkçe.
- Gerçek `~/Desktop`/`~/Downloads` üzerinde **apply/undo yok**; elle doğrulama yalnızca geçici test klasörlerinde.
- Komutlar (proje kökünden): çekirdek `swift test`; uygulama `xcodebuild -project App/Trimly.xcodeproj -scheme TrimlyApp -destination 'platform=macOS' -derivedDataPath .build/xcode test`; smoke `zsh scripts/smoke.sh`.

## Review Focus

1. **Plan dışarıdan (CLI) uygulanmışken uygulamada satır düzenlemek** → net bir hata mesajı, çökme/bozulma yok (test: Task 5 `editAfterExternalApplyShowsError`).
2. **Pencere açıkken kaynak dosyanın silinmesi, sonra Uygula** → sonuç sayfası "Kaynak bulunamadı" ile atlananı gösterir, oturum `failed` olmaz (test: Task 6 `applyReportsVanishedSource`).
3. **Aynı klasör için `start()`'ın iki kez çağrılması** (çift URL / çift tık) → tek tarama, tek plan (test: Task 5 `startIsIdempotent`).
4. **Ollama tarama ortasında düşerse** → öğeler `llmError` ile incelemeye düşer, oturum `failed` olmaz (test: Task 5 `providerFailureKeepsSessionUsable`).
5. **Plan penceresi açıkken ayar değişmesi** → açık plan kendi snapshot'ını korur; "Yeniden tara" yeni ayarı kullanır (test: Task 8 `rescanUsesUpdatedSettings`).

---

## File Structure

```
TrimlyCore (değişen/yeni)
  Sources/TrimlyCore/Execution/DataLock.swift, DataLockError.swift        (yeni)
  Sources/TrimlyCore/Execution/Executor.swift, Undoer.swift, Recovery.swift (async + kilit)
  Sources/TrimlyCore/Planning/PlanEditor.swift, PlanStore.swift          (notReady, bulkReject, latestReady)
  Sources/TrimlyCore/Support/UserMessage.swift, LLMReadiness.swift       (yeni; CLI'den taşınır)
  Sources/trimly/*  (await, UserMessage/LLMReadiness kullanımı, apply durum kontrolü)
App/
  project.yml
  TrimlyApp/App/        TrimlyApp.swift, AppDelegate.swift, AppEnvironment.swift, URLRouter.swift, LaunchState.swift
  TrimlyApp/Shared/     OllamaStatus.swift, StatusBadge.swift, PathFormatting.swift
  TrimlyApp/Start/      StartView.swift
  TrimlyApp/Runs/       RunsModel.swift, RunsList.swift, HistoryView.swift
  TrimlyApp/Plan/       PlanSession.swift, PlanPhase.swift, CategoryGroup.swift, SkipGroup.swift, ApprovalState.swift,
                        PlanWindow.swift, PendingSection.swift, ReadySection.swift, SkippedSection.swift,
                        ItemRow.swift, CategoryGroupHeader.swift, ProgressFooter.swift, ApplySheet.swift, ResultSheet.swift
  TrimlyApp/Settings/   SettingsModel.swift, SettingsView.swift, NamingTab.swift, TargetTab.swift, ModelTab.swift, IgnoreTab.swift
  TrimlyApp/Resources/  Info.plist, Assets.xcassets
  TrimlyAppTests/       URLRouterTests, OllamaStatusTests, RunsModelTests, PlanSessionTests, PlanSessionApplyTests,
                        SettingsModelTests, Fixtures/AppFixture.swift
  (paylaşılan) ../Tests/TrimlyCoreTests/Fixtures/TestFS.swift, MockLLMProvider.swift — project.yml ile test target'a eklenir
```

---

### Task 1: Veri dizini kilidi + async Executor/Undoer

**Files:**
- Create: `Sources/TrimlyCore/Execution/DataLock.swift`, `DataLockError.swift`
- Modify: `Sources/TrimlyCore/Execution/Executor.swift`, `Undoer.swift`, `Recovery.swift`, `Sources/trimly/ApplyCommand.swift`, `UndoCommand.swift`, `Tests/TrimlyCoreTests/Execution/ExecutorTests.swift`, `UndoerTests.swift`
- Test: `Tests/TrimlyCoreTests/Execution/DataLockTests.swift`

**Interfaces:**
- Produces:
  - `public enum DataLockError: Error, Equatable { case busy }`
  - `public final class DataLock { public static func acquire(in: DataDirectory) throws -> DataLock /* flock(LOCK_EX|LOCK_NB) on <root>/lock; busy → DataLockError.busy */; deinit /* close fd → release */ }`
  - `Executor.apply(planID:)` → `@concurrent public func apply(planID: String) async throws -> RunSummary` (ilk iş: `DataLock.acquire`)
  - `Undoer.undo(runID:)` → `@concurrent public func undo(runID: String?) async throws -> UndoSummary` (ilk iş: `DataLock.acquire`)
  - `Recovery.recoverAll(in:)`: kilit alınamazsa (`busy`) hiçbir journal'a dokunmadan `0` döner; alınırsa iş bitince bırakır.
- Kilit aynı süreçte ikinci kez (ayrı `open`) alınamaz — macOS'ta `flock` açık dosya açıklamasına bağlıdır; testler bunu kullanır.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite(.tags(.fileSystem))
struct DataLockTests {
    @Test func secondAcquireIsBusyUntilReleased() throws {
        let data = DataDirectory(root: try TestFS.tempDir())
        try data.ensureExists()
        var first: DataLock? = try DataLock.acquire(in: data)
        #expect(throws: DataLockError.busy) { _ = try DataLock.acquire(in: data) }
        _ = first
        first = nil
        #expect(throws: Never.self) { _ = try DataLock.acquire(in: data) }
    }

    @Test func applyAndUndoFailWhileLocked() async throws {
        let f = try PlannerFixture()
        let plan = try await f.planner(nil).makePlan(root: f.root, useLLM: false)
        let lock = try DataLock.acquire(in: f.data)
        await #expect(throws: DataLockError.busy) { try await Executor(directory: f.data).apply(planID: plan.id) }
        await #expect(throws: DataLockError.busy) { try await Undoer(directory: f.data).undo(runID: nil) }
        _ = lock
    }

    @Test func recoverAllSkipsWhileLocked() throws {
        // pending move journal (dosya aslında `to`'da) + kilit tutulurken recoverAll → 0, satır hâlâ pending;
        // kilit bırakılınca recoverAll → 1
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter DataLockTests` → derleme hatası (`DataLock` yok).
- [ ] **Step 3: Implement** `DataLock`, `DataLockError`; Executor/Undoer'ı `@concurrent async` yap ve kilitle; `recoverAll` kilidi denesin. Mevcut `ExecutorTests`/`UndoerTests` çağrılarını `try await` yap (testler `async` olur); CLI `ApplyCommand`/`UndoCommand` `try await`.
- [ ] **Step 4: Run** — `swift test` → tümü geçer; `swift build && zsh scripts/smoke.sh` → `SMOKE OK`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): data directory lock; apply/undo run off the caller's actor"`

---

### Task 2: Çekirdek yardımcıları — notReady, bulkReject, latestReady, UserMessage, LLMReadiness

**Files:**
- Create: `Sources/TrimlyCore/Support/UserMessage.swift`, `LLMReadiness.swift`
- Modify: `Sources/TrimlyCore/Planning/PlanEditor.swift`, `PlanStore.swift`, `Sources/trimly/Output.swift`, `CLIEnvironment.swift`, `ApplyCommand.swift`
- Test: `Tests/TrimlyCoreTests/Planning/ReviewAndEditorTests.swift` (ek), `Tests/TrimlyCoreTests/Support/UserMessageTests.swift`

**Interfaces:**
- Produces:
  - `PlanEditor.set` → `inProgress` planda `PlanError.notReady`; `PlanEditor.bulkApprove` → `inProgress` planda `0`.
  - `public static func bulkReject(_ plan: inout Plan, categoryID: String?) -> Int` — `skipped` dışındaki eşleşen öğelerde `approved = false`, değişen sayı; `applied`/`inProgress` planda `0`. (Ret güvenli olduğu için kritikleri de kapsar.)
  - `PlanStore.latestReady(root: URL, now: Date) throws -> Plan?` — `state == .ready`, aynı kök (`TargetResolver.samePath`), `createdAt > now - 24 saat`, en yeni.
  - `public enum UserMessage { public static func text(for error: any Error) -> String }` — CLI'deki `Output.message(for:)` gövdesi buraya taşınır + `DataLockError.busy → "Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin."` + `LLMError` durumları (`unreachable → "Ollama erişilemiyor."`, `http(c) → "Ollama hata döndürdü (HTTP c)."`, `malformedResponse`/`folderNotAllowed`/`confidenceOutOfRange → "Model geçersiz yanıt verdi."`). `Output.message` buna delege eder.
  - `public enum LLMReadiness { public static func problem(_ health: ProviderHealth, model: String) -> String? }` — `CLIEnvironment.llmProblem` mantığı (`"Ollama erişilemiyor"`, `"<model> yüklü değil"`, `model + ":latest"` kabul); CLI buna delege eder.
  - CLI `apply`: plan `applied`/`inProgress` ise onay sormadan `UserMessage` ile hata + exit 1.
  - `PlanProgress: Equatable` (uygulamadaki `PlanPhase` için).

- [ ] **Step 1: Write the failing tests**

```swift
// ReviewAndEditorTests'e eklenir
@Test func editingInProgressPlanIsRejected() throws {
    let root = try TestFS.tempDir()
    var plan = Plan.stub(root: root, items: [.stub("a.pdf", in: root, category: "documents", status: .review)], state: .inProgress)
    let id = plan.item("a.pdf").id
    #expect(throws: PlanError.notReady) { try PlanEditor.set(&plan, itemID: id, categoryID: nil, description: nil, approve: true) }
    #expect(PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: true) == 0)
}
@Test func bulkRejectClearsCategoryIncludingCritical() throws {
    // documents: a.pdf approved, b.pdf approved+critical, c.jpg (images) approved → bulkReject(categoryID: "documents") == 2,
    // c.jpg hâlâ approved; skipped öğe değişmez
}
@Test func latestReadyFindsRecentReadyPlanForRoot() async throws {
    // PlannerFixture: makePlan → latestReady(root:now:) == plan.id; başka kök → nil; now+25h → nil; applied plan → nil
}

struct UserMessageTests {
    @Test(arguments: [
        (DataLockError.busy as any Error, "Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin."),
        (PlanError.alreadyApplied as any Error, "Bu plan zaten uygulanmış; yeni bir plan oluşturun."),
        (LLMError.unreachable as any Error, "Ollama erişilemiyor.")
    ])
    func messages(error: any Error, text: String) { #expect(UserMessage.text(for: error) == text) }

    @Test func readiness() {
        #expect(LLMReadiness.problem(ProviderHealth(reachable: false, availableModels: []), model: "qwen3:4b") == "Ollama erişilemiyor")
        #expect(LLMReadiness.problem(ProviderHealth(reachable: true, availableModels: ["llama3.1:latest"]), model: "qwen3:4b") == "qwen3:4b yüklü değil")
        #expect(LLMReadiness.problem(ProviderHealth(reachable: true, availableModels: ["llama3.1:latest"]), model: "llama3.1") == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "ReviewAndEditorTests|UserMessageTests"` → derleme hatası.
- [ ] **Step 3: Implement** yukarıdakileri; CLI'yi delege ettir; `apply` durum kontrolünü onaydan önceye al.
- [ ] **Step 4: Run** — `swift test` → geçer; `swift build && zsh scripts/smoke.sh` → `SMOKE OK`; `trimly apply <uygulanmış plan> --data-dir …` onay sormadan `Hata: Bu plan zaten uygulanmış…` ve exit 1.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): bulk reject, latest ready plan, shared user messages; block edits on unfinished plans"`

---

### Task 3: Xcode projesi iskeleti, URL yönlendirme, uygulama ortamı

**Files:**
- Create: `App/project.yml`, `App/TrimlyApp/App/{TrimlyApp,AppDelegate,AppEnvironment,URLRouter,LaunchState}.swift`, `App/TrimlyApp/Resources/{Info.plist,Assets.xcassets}`, `App/TrimlyAppTests/URLRouterTests.swift`, `App/TrimlyAppTests/Fixtures/AppFixture.swift`
- Modify: `.gitignore` (`App/*.xcodeproj`), `Tests/TrimlyCoreTests/Fixtures/MockLLMProvider.swift` (`@testable import` → `import TrimlyCore`; yalnız public API kullanır)

**Interfaces:**
- Produces:
  - `project.yml`: `packages: { Trimly: { path: .. } }`; `TrimlyApp` (application, sources `TrimlyApp`, `dependencies: [{ package: Trimly, product: TrimlyCore }]`, Info.plist `TrimlyApp/Resources/Info.plist` + `CFBundleURLTypes`, Global Constraints'teki ayarlar); `TrimlyAppTests` (bundle.unit-test, sources `TrimlyAppTests` + `../Tests/TrimlyCoreTests/Fixtures/TestFS.swift` + `../Tests/TrimlyCoreTests/Fixtures/MockLLMProvider.swift`, dependencies `TrimlyApp` + `TrimlyCore`); şema `TrimlyApp` test → `TrimlyAppTests`.
  - `struct AppEnvironment: Sendable { let directory: DataDirectory; let makeProvider: @Sendable (Settings) -> any LLMProvider; let now: @Sendable () -> Date; static let live: AppEnvironment; func loadSettings() -> Settings /* hata → varsayılan */ }`; SwiftUI'a `@Entry var appEnvironment: AppEnvironment = .live`.
  - `enum URLRouter { enum Route: Equatable { case organize(URL) }; enum RouteError: Error, Equatable { case unsupported, missingPath, notAFolder(String) }; static func route(_ url: URL) throws -> Route; static func organizeURL(for folder: URL) -> URL }` — şema `trimly`, host `organize`, `path` query (yüzde kodlu) → standardize dosya URL'si; klasör değilse `notAFolder(path)`.
  - `@MainActor @Observable final class LaunchState { var launchedByURL = false; static let shared }` — AppDelegate `application(_:open:)` set eder (Task 9'da açılış penceresi bunu kullanır).
  - `TrimlyApp` (@main): sahneler `Window("Trimly", id: "start") { StartView() }` (Task 4'e kadar yer tutucu `Text`), `WindowGroup(id: "plan", for: URL.self) { $root in PlanWindow(root: $root) }` (Task 7'ye kadar yer tutucu: kök yolunu gösterir) `.handlesExternalEvents(matching: ["organize"])`, `Window("Geçmiş", id: "history")` (yer tutucu), `Settings` (yer tutucu). Plan penceresi içeriği `onOpenURL` ile `root == nil` ise kökü set eder.
  - `AppDelegate`: `applicationDidFinishLaunching` → `DataDirectory.default.ensureExists()` + `Recovery.recoverAll`; `applicationShouldTerminateAfterLastWindowClosed → true`; `applicationDockMenu` → "Masaüstünü Düzenle" / "İndirilenleri Düzenle" (her biri `NSWorkspace.shared.open(URLRouter.organizeURL(for:))`).

- [ ] **Step 1: Write the failing tests** (`App/TrimlyAppTests/URLRouterTests.swift`)

```swift
@MainActor
struct URLRouterTests {
    @Test func routesEncodedFolderPath() throws {
        let folder = try TestFS.folder("Kişisel Belgeler", in: try TestFS.tempDir())
        let url = URLRouter.organizeURL(for: folder)
        #expect(url.scheme == "trimly" && url.host() == "organize")
        #expect(try URLRouter.route(url) == .organize(folder.standardizedFileURL))
    }
    @Test func rejectsFileAndMissingAndUnknown() throws {
        let file = try TestFS.file("a.txt", in: try TestFS.tempDir())
        #expect(throws: URLRouter.RouteError.notAFolder(file.path)) { try URLRouter.route(URLRouter.organizeURL(for: file)) }
        #expect(throws: URLRouter.RouteError.missingPath) { try URLRouter.route(URL(string: "trimly://organize")!) }
        #expect(throws: URLRouter.RouteError.unsupported) { try URLRouter.route(URL(string: "trimly://delete?path=/tmp")!) }
        #expect(throws: URLRouter.RouteError.unsupported) { try URLRouter.route(URL(string: "https://organize?path=/tmp")!) }
    }
}
```

- [ ] **Step 2: Generate + run to verify failure** — `cd App && xcodegen generate && cd .. && xcodebuild … test` (Global Constraints komutu) → derleme hatası (`URLRouter` yok).
- [ ] **Step 3: Implement** proje dosyaları, `AppEnvironment`, `URLRouter`, `LaunchState`, `AppDelegate`, yer tutucu sahneler.
- [ ] **Step 4: Run** — aynı `xcodebuild … test` → `** TEST SUCCEEDED **`; `swift test` hâlâ geçer. Elle: `open .build/xcode/Build/Products/Debug/Trimly.app` → açılış penceresi; `open "trimly://organize?path=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' <geçici klasör>)"` → kök yolunu gösteren plan penceresi (ekran görüntüsü `screencapture -x`).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): XcodeGen project, URL routing, app environment and scenes"`

---

### Task 4: Ollama durumu + işlemler modeli + açılış penceresi

**Files:**
- Create: `App/TrimlyApp/Shared/{OllamaStatus,StatusBadge,PathFormatting}.swift`, `App/TrimlyApp/Runs/{RunsModel,RunsList}.swift`, `App/TrimlyApp/Start/StartView.swift`
- Test: `App/TrimlyAppTests/{OllamaStatusTests,RunsModelTests}.swift`

**Interfaces:**
- Consumes: `AppEnvironment` (T3), `LLMReadiness`, `UserMessage` (T2), `RunLog`, `Undoer` async (T1)
- Produces:
  - `enum OllamaStatus: Equatable { case unknown, ready, modelMissing(String), unreachable; static func from(_ health: ProviderHealth, model: String) -> OllamaStatus; var label: String /* "Hazır", "<model> yüklü değil", "Ollama erişilemiyor", "Kontrol ediliyor…" */ }`
  - `enum PathFormatting { static func relative(_ url: URL, to root: URL) -> String; static func displayName(_ url: URL) -> String /* "~/Downloads" biçimi */ }`
  - `@MainActor @Observable final class RunsModel { init(environment: AppEnvironment, limit: Int?); private(set) var runs: [RunInfo]; private(set) var lastUndo: UndoSummary?; private(set) var errorMessage: String?; func refresh(); func undo(runID: String) async }` — `limit` nil = hepsi (Geçmiş), 5 = açılış.
  - `StartView`: "Masaüstü" / "İndirilenler" / "Klasör seç…" (`fileImporter(allowedContentTypes: [.folder])`) → `openWindow(id: "plan", value: url)`; `RunsList(model:)`; altta `StatusBadge(status:)` (`.task` içinde `makeProvider(settings).health()`) ve "Ayarlar…" (`SettingsLink`).

- [ ] **Step 1: Write the failing tests**

```swift
struct OllamaStatusTests {
    @Test func mapsHealth() {
        #expect(OllamaStatus.from(ProviderHealth(reachable: false, availableModels: []), model: "qwen3:4b") == .unreachable)
        #expect(OllamaStatus.from(ProviderHealth(reachable: true, availableModels: []), model: "qwen3:4b") == .modelMissing("qwen3:4b"))
        #expect(OllamaStatus.from(ProviderHealth(reachable: true, availableModels: ["qwen3:4b"]), model: "qwen3:4b") == .ready)
    }
}

@MainActor @Suite(.tags(.fileSystem))
struct RunsModelTests {
    @Test func limitsToNewestRuns() async throws {
        // AppFixture: 6 ayrı kök, her biri 1 dosya, plan+apply (now her seferinde +1 sn) → RunsModel(limit: 5).refresh() → 5 run, ilk = en yeni
    }
    @Test func undoRestoresAndRefreshes() async throws {
        // 1 run → undo(runID:) → lastUndo?.restored == 1, runs.first?.undone == true, dosya orijinal yerinde
    }
    @Test func undoErrorBecomesMessage() async throws {
        // olmayan runID → errorMessage == "İşlem bulunamadı: r-yok"
    }
}
```

`AppFixture` (`App/TrimlyAppTests/Fixtures/AppFixture.swift`): `struct AppFixture { let root: URL; let data: DataDirectory; static func empty() throws -> AppFixture /* geçici kök + veri dizini, settings.json: {"recentMinutes":0,"llmEnabled":false} */; static func standard() throws -> AppFixture /* empty + Screenshot 2025-03-14 at 10.22.31.png, download (3).pdf, kimlik.pdf, song.mp3, Album/(3 jpg), .DS_Store; tümü 2 gün önce */; func writeSettings(_ change: (inout Settings) -> Void) throws; func environment(provider: (any LLMProvider)? = nil, now: Date = Date()) -> AppEnvironment; func applyOnce(root: URL? = nil, now: Date = Date()) async throws -> RunSummary }` ve `extension Date { static var feb10Midday: Date }`.

- [ ] **Step 2: Run to verify failure** — `xcodebuild … test` → derleme hatası.
- [ ] **Step 3: Implement** modeller ve view'lar.
- [ ] **Step 4: Run** — `xcodebuild … test` → `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): start window with shortcuts, recent runs and Ollama status"`

---

### Task 5: PlanSession — yükleme, tarama, bölümler, düzenleme

**Files:**
- Create: `App/TrimlyApp/Plan/{PlanSession,PlanPhase,CategoryGroup,SkipGroup,ApprovalState}.swift`
- Test: `App/TrimlyAppTests/PlanSessionTests.swift`

**Interfaces:**
- Consumes: `AppEnvironment`, `OllamaStatus`, `Planner` (`@concurrent makePlan`), `PlanStore.latestReady`, `PlanEditor` (`set`, `bulkApprove`, `bulkReject`), `UserMessage`, `LLMReadiness`
- Produces:
  - `enum PlanPhase: Equatable { case idle, scanning(PlanProgress?), reviewing(PlanProgress?), applying, applied(runID: String), failed(String) }` — Task 2'de çekirdekte `PlanProgress`'e `Equatable` eklenir.
  - `enum ApprovalState: Equatable { case all, none, mixed }`
  - `struct CategoryGroup: Identifiable { let id: String /* categoryID */; let title: String /* ayardaki dilde klasör adı */; let items: [PlanItem]; var approval: ApprovalState }`; `struct SkipGroup: Identifiable { let id: String /* sebep */; let items: [PlanItem] }`
  - `@MainActor @Observable final class PlanSession { init(root: URL, environment: AppEnvironment); let root: URL; private(set) var plan: Plan?; private(set) var phase: PlanPhase; private(set) var banner: String?; private(set) var errorMessage: String?; var searchText: String; var pendingItems: [PlanItem] { get } /* review+critical, aramaya göre, ada göre sıralı */; var readyGroups: [CategoryGroup] { get } /* ready öğeler kategori başına, başlık adına göre sıralı */; var skippedGroups: [SkipGroup] { get }; var approvedCount: Int { get }; var stage2CandidateCount: Int { get } /* (review|critical) && !approved */; var isReadOnly: Bool { get } /* plan.state == .applied */; func start() async; func rescan() async; func cancel(); func setCategory(_ categoryID: String, for itemID: String); func setDescription(_ text: String, for itemID: String); func setApproved(_ approved: Bool, for itemID: String); func setGroupApproved(_ approved: Bool, categoryID: String) }`
- Kararlar:
  - `start()`: zaten başlamışsa (`phase != .idle` veya `plan != nil`) hiçbir şey yapmaz. `PlanStore.latestReady(root:now:)` varsa onu yükler; yoksa tarar. Tarama öncesi `health()` + `LLMReadiness.problem(_, model: stage1Model)`: sorun varsa `banner = "<sorun>; yalnızca kurallar kullanılıyor."` ve `useLLM: false`.
  - İlerleme: `AsyncStream.makeStream(of: PlanProgress.self)`; Planner `progress` kapanışı `continuation.yield`; `withTaskGroup` içinde bir alt görev akışı tüketip `phase`'i günceller, diğeri `makePlan`'i çalıştırır ve bitince `continuation.finish()`. Tarama görevi saklanır; `cancel()` onu iptal eder → `phase = .idle`, `errorMessage = nil` (Planner checkpoint'i diskte).
  - Her düzenleme `PlanEditor` + `PlanStore.save`; hata → `errorMessage = UserMessage.text(for:)`, plan diskten yeniden yüklenir.
  - `setGroupApproved(true)` → `bulkApprove(categoryID:, reviewReason: nil, minConfidence: nil, includeFolders: false)`; `false` → `bulkReject(categoryID:)`.
  - `rescan()`: mevcut planı bırakır, `plan = nil`, `phase = .idle`, ayarları yeniden yükler, `start()`'ın tarama yolunu **latestReady'yi atlayarak** çalıştırır.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite(.tags(.fileSystem))
struct PlanSessionTests {
    // AppFixture.standard(): Screenshot…png, download (3).pdf, kimlik.pdf, song.mp3, Album/ (jpg), .DS_Store
    @Test func scanBuildsSections() async throws {
        let f = try AppFixture.standard()
        let session = PlanSession(root: f.root, environment: f.environment())
        await session.start()
        #expect(session.phase == .idle && session.plan?.state == .ready)
        #expect(session.pendingItems.map(\.name) == ["Album", "download (3).pdf", "kimlik.pdf"])
        #expect(session.readyGroups.map(\.id).sorted() == ["audio", "screenshots"])
        #expect(session.skippedGroups.map(\.id) == ["Sistem dosyası"])
        #expect(session.approvedCount == 2)
    }
    @Test func loadsExistingReadyPlanInsteadOfRescanning() async throws {
        // CLI benzeri: Planner ile plan üret + bir öğeyi PlanEditor ile reddet + kaydet → session.start() → aynı plan.id, ret korunmuş
    }
    @Test(.tags(.edgeCase)) func startIsIdempotent() async throws {
        // async let a = session.start(); async let b = session.start(); await a; await b → PlanStore.list() aynı kök için 1 plan
    }
    @Test func searchFiltersPendingItems() async throws { /* searchText = "kim" → pendingItems == ["kimlik.pdf"] */ }
    @Test func editsPersistToDisk() async throws {
        // setCategory("invoices", for: download id) + setDescription("Kira Ocak") + setApproved(true) →
        // store.load(id:) öğesi decidedBy .manual, approved, hedef "…_Fatura_Kira-Ocak.pdf"
    }
    @Test func groupToggleNeverApprovesCritical() async throws {
        // setGroupApproved(false, "screenshots") → grup .none; setGroupApproved(true, "screenshots") → .all;
        // kimlik.pdf (kritik) hiçbir grup işleminden sonra onaylı değil
    }
    @Test(.tags(.edgeCase)) func editAfterExternalApplyShowsError() async throws {
        // session.start(); dışarıdan Executor.apply(planID:); session.setApproved(true, for: kimlik id) →
        // errorMessage == "Bu plan zaten uygulanmış; yeni bir plan oluşturun.", session.isReadOnly == true
    }
    @Test(.tags(.edgeCase)) func providerFailureKeepsSessionUsable() async throws {
        // writeSettings { llmEnabled = true }; provider: HealthyProvider(wrapping: MockLLMProvider(defaultResult: .failure(LLMError.unreachable)))
        // → phase == .idle, banner == nil, download (3).pdf reviewReason == .llmError
    }
    @Test func unreachableOllamaShowsBannerAndUsesRules() async throws {
        // health unreachable → banner == "Ollama erişilemiyor; yalnızca kurallar kullanılıyor.", download → .weakRuleNoLLM
    }
    @Test func cancellationKeepsCheckpointAndResumes() async throws {
        // empty() + 5 adet belge<i>.pdf, writeSettings { llmEnabled = true; batchSize = 2 };
        // provider: HealthyProvider(wrapping: MockLLMProvider(defaultResult: Belgeler 0.9, cancelAfterCalls: 3)) → start() →
        // phase == .idle, errorMessage == nil, plan == nil, PlanStore.latestResumable != nil;
        // yeni session (sağlam mock) start() → aynı plan id, state .ready
    }
}
```

`MockLLMProvider.health()` modelsiz döndüğü için `AppFixture`, `availableModels: ["qwen3:4b", "ministral-3:14b"]` döndüren ince bir sarmalayıcı `HealthyProvider(wrapping:)` sağlar (`App/TrimlyAppTests/Fixtures/HealthyProvider.swift`, actor değil `struct`, `LLMProvider` çağrılarını sarmalanana iletir).

- [ ] **Step 2: Run to verify failure** — `xcodebuild … test` → derleme hatası.
- [ ] **Step 3: Implement** `PlanSession` ve yardımcı tipler.
- [ ] **Step 4: Run** — `xcodebuild … test` → `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): plan session with scan, sections, edits and cancellation"`

---

### Task 6: PlanSession — 2. aşama, uygula, geri al

**Files:**
- Modify: `App/TrimlyApp/Plan/PlanSession.swift`
- Test: `App/TrimlyAppTests/PlanSessionApplyTests.swift`

**Interfaces:**
- Produces (PlanSession'a eklenir):
  - `private(set) var lastRun: RunSummary?; private(set) var lastUndo: UndoSummary?`
  - `var stage2Available: Bool { get }` — son sağlık kontrolünde `LLMReadiness.problem(_, model: stage2Model) == nil` ve `stage2CandidateCount > 0`.
  - `func runStage2() async` — `phase = .reviewing(_)` (aynı akış deseni), `Planner.review(planID:)`, plan yenilenir.
  - `var applySummary: (count: Int, byCategory: [(title: String, count: Int)], criticalApproved: [PlanItem]) { get }` — onay sayfası için.
  - `func apply() async` — `phase = .applying` → `Executor.apply` → `lastRun`, plan diskten yeniden yüklenir, `phase = .applied(runID:)`; hata → `phase = .failed(UserMessage…)`.
  - `func undoLastApply() async` — `Undoer.undo(runID: lastRun.runID)` → `lastUndo`; `RunsModel` dinlemiyorsa sorun değil (açılış/geçmiş `refresh` ile görür).

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite(.tags(.fileSystem))
struct PlanSessionApplyTests {
    @Test func applyMovesApprovedAndBecomesReadOnly() async throws {
        // start → apply → phase == .applied(runID: lastRun!.runID), lastRun.moved == 2, isReadOnly, ekran görüntüsü hedefte
    }
    @Test(.tags(.edgeCase)) func applyReportsVanishedSource() async throws {
        // start → song.mp3'ü sil → apply → lastRun.skipped içinde reason "Kaynak bulunamadı", phase .applied (failed değil)
    }
    @Test func undoAfterApplyRestores() async throws { /* apply → undoLastApply → lastUndo.restored == 2, dosyalar yerinde */ }
    @Test func applyWhileLockedFails() async throws {
        // DataLock.acquire tutulurken apply → phase == .failed("Başka bir Trimly işlemi sürüyor; bitince tekrar deneyin.")
    }
    @Test func stage2PromotesAndNeverTouchesApproved() async throws {
        // HealthyProvider(MockLLMProvider(defaultResult: Faturalar 0.9)) → start(useLLM yokmuş gibi kurallar: ayarda llmEnabled=false ile tara),
        // sonra llmEnabled=true yapıp runStage2 → download (3).pdf .ready + approved; kullanıcı onayladığı kimlik.pdf hedefi değişmedi
    }
    @Test func applySummaryListsCriticalApprovals() async throws {
        // kimlik.pdf setApproved(true) → applySummary.criticalApproved.map(\.name) == ["kimlik.pdf"], count == approvedCount
    }
}
```

- [ ] **Step 2: Run to verify failure** — `xcodebuild … test` → derleme hatası.
- [ ] **Step 3: Implement** yukarıdakileri.
- [ ] **Step 4: Run** — `xcodebuild … test` → `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): stage-2 review, apply and undo in plan session"`

---

### Task 7: Plan penceresi view'ları

**Files:**
- Create: `App/TrimlyApp/Plan/{PlanWindow,PendingSection,ReadySection,SkippedSection,ItemRow,CategoryGroupHeader,ProgressFooter,ApplySheet,ResultSheet}.swift`
- Modify: `App/TrimlyApp/App/TrimlyApp.swift` (yer tutucuyu `PlanWindow` ile değiştir)

**Interfaces:**
- Consumes: `PlanSession` (T5–T6), `PathFormatting`, `StatusBadge`
- Produces: tasarım §5.2 düzeni:
  - `PlanWindow(root: Binding<URL?>)`: kök nil ise "Klasör bekleniyor" boş durumu; değilse `@State var session` (kök değişince yeni oturum), `.task { await session.start() }`, pencere başlığı `PathFormatting.displayName(root)`; araç çubuğu: arama (`searchable`), "Yeniden tara", "Detaylı incele (n)" (`stage2Available` değilse devre dışı + yardım metni), "Uygula (n)" (`approvedCount == 0` veya `isReadOnly` ise devre dışı); `banner` varsa üstte uyarı şeridi; `errorMessage` için `alert`.
  - `List` içinde üç `Section`: `PendingSection` (açık), `ReadySection` (kategori başına `DisclosureGroup` + `CategoryGroupHeader` üç durumlu onay kutusu), `SkippedSection` (kapalı `DisclosureGroup`, sebebe göre).
  - `ItemRow(item:, root:, session:, editable:)`: durum simgesi (kritik `lock.fill`, inceleme `questionmark.circle`, klasör `folder`, hazır `checkmark.circle`) + `accessibilityLabel` ("Kritik", "İnceleme", …); ad; → göreli hedef; kategori `Picker` (ayardaki dilde klasör adları, değer `categoryID`); açıklama `TextField` (klasörlerde yok; `onSubmit` + odak kaybında `setDescription`); onay `Toggle` (`.checkbox` stili); alt satır sebep · güven (`%.2f`) · karar kaynağı. `isReadOnly` ise tüm kontroller devre dışı.
  - `ProgressFooter`: `phase` `.scanning/.reviewing` ise `ProgressView(value:total:)` + "LLM n/m" + "İptal".
  - `ApplySheet`: `applySummary` (sayı, kategori dağılımı, kritik onaylılar 🔒 listesi), "Uygula" (varsayılan değil — `.keyboardShortcut` yok) / "Vazgeç".
  - `ResultSheet`: `lastRun` (taşınan, atlanan sebepli liste, hatalı), "Geri Al" → `undoLastApply` sonrası `lastUndo` özeti, "Finder'da göster" (`NSWorkspace.shared.activateFileViewerSelecting([root])`), "Kapat".

- [ ] **Step 1: Build** — `xcodebuild … build` → `** BUILD SUCCEEDED **` (view'lar test edilmez; davranış T5–T6 testlerinde).
- [ ] **Step 2: Run tests** — `xcodebuild … test` → `** TEST SUCCEEDED **`.
- [ ] **Step 3: Elle doğrula** — geçici klasör (smoke'taki gibi dosyalar + `settings.json` `recentMinutes: 0`, `llmEnabled: false`) ile `open "trimly://organize?path=…"`; `screencapture -x` ile görüntü al ve oku: üç bölüm, sayılar, kilit simgesi görünür. Gerçek klasörde açılmaz.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(app): plan window with pending-first layout, apply and result sheets"`

---

### Task 8: Ayarlar

**Files:**
- Create: `App/TrimlyApp/Settings/{SettingsModel,SettingsView,NamingTab,TargetTab,ModelTab,IgnoreTab}.swift`
- Modify: `App/TrimlyApp/App/TrimlyApp.swift` (`Settings { SettingsView() }`)
- Test: `App/TrimlyAppTests/SettingsModelTests.swift`

**Interfaces:**
- Consumes: `AppEnvironment`, `SettingsStore`, `NamingTemplate`, `DateResolver.dayString`, `OllamaStatus`
- Produces:
  - `@MainActor @Observable final class SettingsModel { init(environment: AppEnvironment); var settings: Settings /* didSet → SettingsStore.save; hata → saveError */; private(set) var saveError: String?; private(set) var availableModels: [String]; private(set) var status: OllamaStatus; func refreshHealth() async; func namingExample(for preset: NamingPreset) -> String }`
  - `namingExample`: `NamingTemplate.fileName(preset:, day: DateResolver.dayString(environment.now()), categoryTag: settings.category(id: "invoices")!.tag.value(settings.categoryLanguage), description: settings.categoryLanguage == .tr ? "Enerjisa-Ocak" : "Enerjisa-January", originalName: "download (3).pdf", fileExtension: "pdf")`.
  - Sekmeler tasarım §5.5'teki gibi; Adlandırma'da her preset `Picker(.radioGroup)` satırında örnek ad (`.monospaced`, ikincil renk); Model'de model seçicileri `availableModels` boşsa `TextField`; Hariç tutma'da glob ve proje işareti listeleri ekle/sil. Altta bir satır: "Değişiklikler yeni planlarda geçerli olur."

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite(.tags(.fileSystem))
struct SettingsModelTests {
    @Test func changesAreSavedImmediately() throws {
        let f = try AppFixture.empty()
        let model = SettingsModel(environment: f.environment())
        model.settings.namingPreset = .categoryDescription
        #expect(try SettingsStore.load(from: f.data).namingPreset == .categoryDescription)
    }
    @Test func namingExamplesFollowPresetAndLanguage() throws {
        let f = try AppFixture.empty()
        let model = SettingsModel(environment: f.environment(now: .feb10Midday))
        #expect(model.namingExample(for: .dateCategoryDescription) == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(model.namingExample(for: .keepOriginal) == "download (3).pdf")
        model.settings.categoryLanguage = .en
        #expect(model.namingExample(for: .categoryDescription) == "Invoice_Enerjisa-January.pdf")
    }
    @Test(.tags(.edgeCase)) func rescanUsesUpdatedSettings() async throws {
        // session.start() (varsayılan preset) → hedef "2025-…_Ekran-Goruntusu_10-22-31.png";
        // SettingsModel ile preset = .keepOriginal → açık plan hedefi değişmez; session.rescan() → hedef orijinal adla
    }
    @Test func healthPopulatesModels() async throws {
        // HealthyProvider → refreshHealth() → status == .ready, availableModels == ["qwen3:4b", "ministral-3:14b"]
    }
}
```

`.feb10Midday` app test target'ta `AppFixture.swift` içinde tanımlanır (çekirdek test fixture'ı paylaşılmıyor).

- [ ] **Step 2: Run to verify failure** — `xcodebuild … test` → derleme hatası.
- [ ] **Step 3: Implement** model ve sekmeler.
- [ ] **Step 4: Run** — `xcodebuild … test` → `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): settings window with live naming examples"`

---

### Task 9: Geçmiş penceresi, açılış davranışı ve elle doğrulama

**Files:**
- Create: `App/TrimlyApp/Runs/HistoryView.swift`
- Modify: `App/TrimlyApp/App/TrimlyApp.swift`, `AppDelegate.swift`, `App/TrimlyApp/Start/StartView.swift`
- Create: `docs/superpowers/reports/2026-11-21-phase2-manual-verification.md`

**Interfaces:**
- Consumes: `RunsModel` (T4), `LaunchState` (T3)
- Produces:
  - `HistoryView`: `RunsModel(limit: nil)`; tablo (tarih, kök, taşınan, durum); seçili işlem için "Geri Al" → `lastUndo` özeti; "Yenile". Menü: `CommandGroup(after: .windowArrangement)` içinde "Geçmiş" (⌘Y) → `openWindow(id: "history")`.
  - Açılış davranışı (tasarım §5.1): URL ile başlatmada açılış penceresi gösterilmez; macOS 15+ için koşullu `defaultLaunchBehavior`, macOS 14'te `StartView` `LaunchState.shared.launchedByURL` ise plan penceresi göründükten **sonra** `dismissWindow(id: "start")`. Sıfır pencereli ara durum oluşmaz.
  - Plan penceresi kapanınca (`onDisappear`) `session.cancel()`.

- [ ] **Step 1: Build + test** — `xcodebuild … test` → `** TEST SUCCEEDED **`; `swift test` → geçer; `zsh scripts/smoke.sh` → `SMOKE OK`.
- [ ] **Step 2: Elle doğrulama** (yalnız geçici klasörler; her senaryo için `screencapture -x` görüntüsü ve `pgrep -x Trimly` sonucu rapora):
  1. Uygulama kapalıyken `open "trimly://organize?path=<geçici>"` → yalnızca plan penceresi; 5 sn sonra `pgrep` hâlâ çalışıyor.
  2. Ayarlar açıkken diğer pencereleri kapat → uygulama çalışıyor; Ayarlar kapanınca sonlanıyor.
  3. Tarama sürerken plan penceresini kapat → uygulama sonlanır; `plans/` altında `inProgress` veya `ready` plan var; yeniden açınca devam eder.
  4. Dock menüsünden "İndirilenleri Düzenle" görünür (yalnızca menünün varlığı; gerçek klasörde **Uygula yapılmaz**).
  Pencere kapatma/menü etkileşimi `osascript` (System Events) ile yapılamıyorsa (Erişilebilirlik izni), senaryo 2–4 için kullanıcıdan elle doğrulama istenir ve rapora "kullanıcı doğrulayacak" yazılır.
- [ ] **Step 3: Commit** — `git add -A && git commit -m "feat(app): history window, URL-launch behaviour and manual verification report"`
