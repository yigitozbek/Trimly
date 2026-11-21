# Trimly Faz 3a — İç İçe Tarama + Boş Klasörler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derinlik sınırına kadar iç içe tarama, klasör bazında dağıt/bütün tut, kategori klasörlerinin içinin düzenlenmesi (merkezi arşive göç), isteğe bağlı boş klasör kaldırma; çekirdek + CLI + uygulama.

**Architecture:** Tarayıcı ağacı çıkarır; Planner klasör modlarını deterministik belirler, yalnız **etkin** öğeleri LLM'e yollar; `CoverageResolver` kapsamayı, `TargetAssigner` hedefleri tüm plan için yeniden hesaplar. Executor/Undoer journal'ı tek ters sırada oynatır (`rmdir` → taşımalar → `mkdir`).

**Tech Stack:** Swift 6.4, TrimlyCore, swift-argument-parser, SwiftUI (macOS 14+), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-phase3-nested-tags-trash-design.md` (§5.1–5.5, 5.8–5.9; 3b/3c bu planın dışında)

## Global Constraints

- Mevcut güvenlik ilkeleri: silme yok (tek istisna: `removeEmptyFolders` ile boş klasör + tek `.DS_Store`), üzerine yazma yok, her işlem journal'lı ve `DataLock` altında, kritik öğe otomatik onaylanmaz ve içeriği LLM'e gitmez — her seviyede.
- `Plan.currentEngineVersion = 3`.
- Varsayılanlar: `scanDepth = 3` (seviye 1 = kökün doğrudan çocukları; 3 → `depth` 0, 1, 2), `distributeThreshold = 0.8`, `removeEmptyFolders = false`; öğe sınırı 5.000.
- Proje klasörlerinin (her seviyede `IgnoreRules` proje işaretleri) içine inilmez.
- Kapsanmış (`covered`) öğe: onaylanmaz, hedefi yok, LLM'e gitmez (yalnız kurallar).
- Proje skill'leri (`swift-concurrency-pro`, `swift-testing-pro`, `swiftui-pro`) ve "her tür kendi dosyasında" kuralı.
- Arayüz/CLI metinleri Türkçe. Gerçek klasörlerde yalnız `plan` (salt okunur); apply/undo yalnız geçici klasörlerde.
- Komutlar: `swift test`; `cd App && xcodegen generate && cd .. && xcodebuild -project App/Trimly.xcodeproj -scheme TrimlyApp -destination 'platform=macOS' -derivedDataPath .build/xcode test`; `zsh scripts/smoke.sh`.

## Review Focus

1. **İndirmesi süren dosya içeren alt klasör** → klasör bütün olarak taşınamaz; mod zorla `distribute`, çocuklar tek tek değerlendirilir (test: Task 5 `folderWithRecentOrPartialChildCannotMoveAsUnit`).
2. **Merkezi arşivin kendisini düzenlemek** (kök = `archiveRoot`) → yerinde olanlar "Zaten düzenli", iç içe yıl klasörü üretilmez (test: Task 5 `scanningTheArchiveItselfProposesNothing`).
3. **Farklı alt klasörlerde aynı ad** → aynı kategoriye giderken deterministik `_2` (test: Task 4 `sameNamesFromDifferentFoldersGetSuffixes`).
4. **Kullanıcının önceden boş bıraktığı klasör** → "boş klasörleri kaldır" açıkken bile dokunulmaz; kök asla kaldırılmaz (test: Task 6 `preexistingEmptyFoldersAndRootAreLeftAlone`).
5. **5.000 öğe sınırını aşan ağaç** → daha derine inilmez, plan kullanılabilir, uyarı görünür (test: Task 2 `stopsDescendingAtLimit`, Task 8 `truncatedScanShowsNotice`).

---

## File Structure

```
Sources/TrimlyCore/
  Model/FolderMode.swift (yeni) · FileItem.swift, PlanItem.swift (+ geriye uyumlu decode), Plan.swift (+ truncated, engine 3),
  Model/ReviewReason.swift (+ mixedFolder), Settings.swift (+ scanDepth, distributeThreshold, removeEmptyFolders)
  Scan/ScanTree.swift (yeni) · FolderScanner.swift (+ scanTree)
  Rules/IgnoreRules.swift (kategori klasörü artık atlanmaz; kategori/yıl klasörlerine son-değişiklik kuralı uygulanmaz)
  Planning/CoverageResolver.swift (yeni) · FolderModeDecider.swift (yeni) · Planner.swift · Planner+Review.swift · PlanEditor.swift (+ setFolderMode) · PlanStats.swift
  Naming/TargetAssigner.swift (kapsanan/dağıtılan atlanır)
  Execution/JournalOp.swift (+ rmdir) · Executor.swift (+ boş klasör) · Undoer.swift (tek ters sıra) · Recovery.swift (+ rmdir)
  LLM/ClassificationRequest.swift, PromptBuilder.swift (+ relativePath)
Sources/trimly/ Output.swift (göreli yol, mod) · SetCommand.swift (+ --mode)
App/TrimlyApp/Plan/ PlanSession.swift (+ pendingGroups, setFolderMode, scanNotice; notice kalkar) · PendingGroup.swift · FolderModePicker.swift · PendingSection.swift · ItemRow.swift
App/TrimlyApp/Settings/ TargetTab.swift (+ derinlik, boş klasör)
```

---

### Task 1: Model alanları (geriye uyumlu)

**Files:** Model dosyaları yukarıdaki gibi; Test: `Tests/TrimlyCoreTests/Model/SettingsTests.swift`, `Tests/TrimlyCoreTests/Model/PlanItemDecodingTests.swift`

**Interfaces — Produces:**
- `public enum FolderMode: String, Codable, Sendable { case keep, distribute }`
- `FileItem` + `relativePath: String` (varsayılan `name`), `depth: Int` (0), `parentRelativePath: String?` (nil) — init'e sona varsayılanlı parametreler.
- `PlanItem` + `relativePath: String`, `depth: Int`, `parentID: String?`, `folderMode: FolderMode?`, `covered: Bool` — init'e varsayılanlı (`relativePath` varsayılan `name`). Özel `init(from:)`: eksik alanlar → `relativePath = name`, `depth = 0`, `parentID = nil`, `folderMode = nil`, `covered = false` (kodlama sentezli kalır).
- `ReviewReason.mixedFolder`; `Plan.truncated: Bool` (varsayılan false, `decodeIfPresent`); `Plan.currentEngineVersion = 3`.
- `Settings`: `scanDepth = 3`, `distributeThreshold = 0.8`, `removeEmptyFolders = false` (+ `decodeIfPresent`).
- `JournalOp.rmdir`.

- [ ] **Step 1: Failing tests** — `defaultsMatchSpec`'e `scanDepth == 3 && distributeThreshold == 0.8 && removeEmptyFolders == false`; `PlanItemDecodingTests.decodesPhase2ItemWithoutTreeFields` (Faz 2 biçimli JSON → `relativePath == name`, `depth == 0`, `covered == false`, `folderMode == nil`); `planWithoutTruncatedDecodes`; `engineVersionIsThree`.
- [ ] **Step 2: RED** — `swift test --filter "SettingsTests|PlanItemDecodingTests"` → derleme hatası.
- [ ] **Step 3: Implement.** `ReviewReason`'a eklenen durum için `switch` kullanan yerlere (CLI `Output.reviewLabel`, app `ItemFormatting.reviewLabel`) etiket: `"karışık klasör: dağıt / bütün tut seçin"`.
- [ ] **Step 4: GREEN** — `swift test` + app testleri derlenir/geçer.
- [ ] **Step 5: Commit** — `feat(core): tree fields on items, folder modes, nested-scan settings`

---

### Task 2: Ağaç tarama

**Files:** Create `Sources/TrimlyCore/Scan/ScanTree.swift`; Modify `FolderScanner.swift`; Test `Tests/TrimlyCoreTests/Scan/FolderScannerTests.swift`

**Interfaces — Produces:**
- `public struct ScanTree: Sendable { public let items: [FileItem]; public let truncated: Bool }`
- `FolderScanner.scanTree(root: URL, maxDepth: Int, limit: Int = 5_000, shouldDescend: (FileItem) -> Bool) throws -> ScanTree` — önce genişlik (BFS), `depth < maxDepth` öğeler; yalnız `kind == .folder` ve `shouldDescend == true` klasörlere inilir ve yalnız `depth + 1 < maxDepth` ise. Öğeler: üst seviye ada göre, sonra her klasörün çocukları; `relativePath` = köke göre. Sınır dolunca yeni öğe eklenmez, `truncated = true`. İnilen klasörlerin `folderExtensionHistogram`'ı **tüm dahil edilmiş alt dosyalardan** (gizliler hariç) yeniden hesaplanır; inilmeyenler eski (doğrudan çocuk) histogramı korur. `scan(root:)` = `scanTree(maxDepth: 1)` ile aynı sonucu verir.

- [ ] **Step 1: Failing tests** — `scanTreeDescendsToDepth` (kök/`A`/`B`/`c.txt` + `A/x.pdf`; maxDepth 3 → relativePath'ler `["A", "A/B", "A/x.pdf", "A/B/c.txt"]` içerir, depth'ler 0,1,1,2; maxDepth 2 → `A/B/c.txt` yok); `shouldDescendIsHonoured` (`proj/.git` + `proj/a.txt`; predicate `name != "proj"` → `proj/a.txt` yok); `histogramCountsDescendants` (`Album/a.jpg`, `Album/alt/b.jpg`, `Album/alt/c.jpg` → `["jpg": 3]`); `(.tags(.edgeCase)) stopsDescendingAtLimit` (12 dosyalı ağaç, limit 5 → `items.count == 5`, `truncated`); `topLevelScanUnchanged` (`scan(root:)` adları == `scanTree(maxDepth: 1)` adları).
- [ ] **Step 2: RED** · **Step 3: Implement** · **Step 4: GREEN** (`swift test --filter FolderScannerTests`)
- [ ] **Step 5: Commit** — `feat(core): depth-limited tree scan with descendant histograms`

---

### Task 3: Hariç tutma kurallarının güncellenmesi

**Files:** Modify `Sources/TrimlyCore/Rules/IgnoreRules.swift`, `App/TrimlyApp/Plan/PlanSession.swift` + `PlanContent.swift` (Faz 2 `notice` ve satırı kaldırılır — kaldırılan sabiti kullanıyordu), `App/TrimlyAppTests/PlanSessionTests.swift` (iki `notice` testi kaldırılır); Test `Tests/TrimlyCoreTests/Rules/IgnoreRulesTests.swift`

**Interfaces — Produces:**
- Kategori klasörü (yalnız `depth == 0`, adı `allCategoryFolderNames` içinde) artık **atlanmaz**; `IgnoreRules.categoryFolderReason` kaldırılır.
- `public func isCategoryFolder(_ item: FileItem) -> Bool` (depth 0 + ad) ve `public func isYearFolderInCategory(_ item: FileItem) -> Bool` (`depth == 1`, ad `^(19|20)\d{2}$`, `parentRelativePath` bir kategori klasörü).
- Son-değişiklik kuralı bu iki klasör türüne uygulanmaz (Trimly onlara dosya taşıdığı için hep yeni görünürler).

- [ ] **Step 1: Failing tests** — `categoryFoldersAreNoLongerSkipped` (eski `categoryFoldersAndGlobs`'taki iki beklenti `nil` olur); `recentCategoryAndYearFoldersAreNotSkipped` (`.stub("Faturalar", kind: .folder, modifiedAt: now)` → nil; yıl klasörü stub'ı `depth 1`, parent `Faturalar`, recent → nil; sıradan recent klasör → hâlâ "Son 60 dakikada değişti").
- [ ] **Step 2–4: RED → Implement → GREEN** (`FileItem.stub`'a `depth:` ve `parent:` parametreleri eklenir)
- [ ] **Step 5: Commit** — `feat(core): category folders are scanned, not skipped`

---

### Task 4: Kapsama, klasör modu düzenleme, hedefler

**Files:** Create `Sources/TrimlyCore/Planning/CoverageResolver.swift`; Modify `PlanEditor.swift`, `Naming/TargetAssigner.swift`; Test `Tests/TrimlyCoreTests/Planning/CoverageTests.swift`

**Interfaces — Produces:**
- `public enum CoverageResolver { public static func apply(_ plan: inout Plan) }` — `parentID` zinciri boyunca: atası `keep` olan öğe `covered = true` (ve `approved = false`); diğerleri `false`. `distribute` klasör: `target = nil`, `approved = false`.
- `TargetAssigner.assign`: `covered` öğeler ve `distribute` klasörler atlanır (`target = nil`).
- `PlanEditor.setFolderMode(_ plan: inout Plan, itemID: String, mode: FolderMode) throws` — `ready` plan; klasör değilse `PlanError.notAFolder`; kategori/yıl klasörü (`skipReason` "…içi düzenlenir") ise `PlanError.folderModeFixed`. `keep` → klasör `status = .review`, `reviewReason = .folder`, `approved = false`; `distribute` → `status = .review`, `reviewReason = .mixedFolder`. Sonra `CoverageResolver.apply` + `TargetAssigner.assign`; yeni etkinleşen çocukların `approved` değeri Planner varsayılanıyla (ready + kritik değil + dosya) yeniden hesaplanır.
- `PlanError` + `notAFolder`, `folderModeFixed`; `UserMessage` metinleri: "Bu öğe bir klasör değil.", "Bu klasörün modu sabit (Trimly kategori klasörü)."

- [ ] **Step 1: Failing tests** (plan stub'larıyla, disk yok) — `keepFolderCoversDescendants`; `distributeFolderHasNoTargetAndChildrenGetTargets`; `switchingModesRecomputesCoverageAndApprovals` (distribute→keep: çocuklar covered ve onaysız; keep→distribute: ready çocuk tekrar onaylı, kritik çocuk onaysız); `fixedModeFolderRejectsChange` (`folderModeFixed`); `(.tags(.edgeCase)) sameNamesFromDifferentFoldersGetSuffixes` (`A/fatura.pdf`, `B/fatura.pdf` aynı kategori ve açıklama → hedef adlar `…pdf` ve `…_2.pdf`, sıra relativePath'e göre deterministik).
- [ ] **Step 2–4: RED → Implement → GREEN**. `TargetAssigner` sıralaması `name` yerine `relativePath`.
- [ ] **Step 5: Commit** — `feat(core): coverage resolver and folder mode editing`

---

### Task 5: Planner — iç içe akış

**Files:** Create `Sources/TrimlyCore/Planning/FolderModeDecider.swift`; Modify `Planner.swift`, `Planner+Review.swift`, `PlanStats.swift`, `LLM/ClassificationRequest.swift`, `LLM/PromptBuilder.swift`; Test `Tests/TrimlyCoreTests/Planning/NestedPlannerTests.swift`

**Interfaces — Produces:**
- `enum FolderModeDecider { static func mode(for folder: FileItem, descended: Bool, hasRecentOrPartialDescendant: Bool, settings: Settings) -> FolderMode }` — inilmediyse `keep`; yeni/yarım çocuk varsa `distribute`; histogramda tek kategori payı ≥ `distributeThreshold` → `keep`; aksi `distribute`.
- Planner akışı: `scanTree(maxDepth: settings.scanDepth, shouldDescend: { ignore.skipReason(for: $0) == nil })`; öğe kimliği yine yol özeti; `parentID` = ebeveyn yolunun kimliği.
  - Kategori klasörü → `skipped`, `skipReason = "Trimly kategori klasörü (içi düzenlenir)"`, `folderMode = .distribute`; yıl klasörü → `"Yıl klasörü (içi düzenlenir)"`, `.distribute`.
  - Diğer klasörler: `FolderModeDecider`; `distribute` → `status .review`, `reviewReason .mixedFolder`; `keep` → bugünkü klasör akışı (kural/LLM, `review/.folder`).
  - Önce modlar → `CoverageResolver` → yalnız **etkin** zayıf öğeler LLM kuyruğuna; kapsanmışlar yalnız kurallarla (`weakRuleNoLLM` yedeği).
  - `ClassificationRequest.relativePath: String?`; istemde `Konum: <üst klasör>/` satırı (üst seviyede yok).
  - Bitiş: `TargetAssigner` + varsayılan onay (`ready && !critical && kind != .folder && !covered`); `plan.truncated = tree.truncated`.
  - `review(planID:)` adayları kapsanmışları içermez.
  - `PlanStats` kapsanmış öğeleri saymaz.

- [ ] **Step 1: Failing tests** (geçici ağaçlar, `recentMinutes = 0` olan PlannerFixture):
  - `mixedFolderIsDistributedAndUniformFolderKept` — `Rastgele/{a.pdf,b.jpg,c.dmg}` → Rastgele `.mixedFolder`, çocukları etkin; `Tatil/{1..5}.jpg` → keep, çocuklar covered.
  - `inPlaceCategoryFolderContentsAreAlreadyOrganized` — `Faturalar/2025-02-10_Fatura_Enerjisa.pdf` (inPlace) → `skipReason == "Zaten düzenli"`.
  - `centralModeMigratesCategoryFolderContents` — aynı ağaç, `targetMode = .central`, `archiveRoot = <geçici arşiv>` → öğe `ready`, onaylı, hedef `<arşiv>/Faturalar/2025-02-10_Fatura_Enerjisa.pdf`.
  - `(.tags(.edgeCase)) scanningTheArchiveItselfProposesNothing` — kök = arşiv, `yearSubfolders = true`, `Faturalar/2025/2025-02-10_Fatura_Enerjisa.pdf` → "Zaten düzenli"; `2025` klasörü `"Yıl klasörü (içi düzenlenir)"`.
  - `(.tags(.edgeCase)) folderWithRecentOrPartialChildCannotMoveAsUnit` — `Indirme/{1..4}.jpg, x.crdownload` → mod distribute.
  - `projectSubfolderIsNotEntered` — `Rastgele/proj/.git` + `Rastgele/proj/a.txt` → `a.txt` planda yok, `proj` skipped "Proje klasörü (.git)".
  - `coveredItemsNeverReachTheLLM` — mock istekleri yalnız etkin öğeleri içerir; istekte `relativePath == "Rastgele/a.pdf"`.
  - `criticalStaysCriticalAtDepth` — `Rastgele/kimlik.pdf` → critical, onaysız, içerik gönderilmez.
- [ ] **Step 2–4: RED → Implement → GREEN** (`swift test`); mevcut testlerden "kategori klasörü atlanır" beklentisi taşıyanlar (`rerunAfterApplyFindsNothing`) yeni davranışa göre güncellenir: kategori klasörü skipReason `"Trimly kategori klasörü (içi düzenlenir)"`, içindekiler "Zaten düzenli".
- [ ] **Step 5: Commit** — `feat(core): nested planning with folder modes and archive migration`

---

### Task 6: Boş klasörler, tek ters sırada geri alma

**Files:** Modify `Executor.swift`, `Undoer.swift`, `Recovery.swift`; Test `Tests/TrimlyCoreTests/Execution/EmptyFolderTests.swift`

**Interfaces — Produces:**
- Executor: taşımalardan sonra `settingsSnapshot.removeEmptyFolders` ise, içinden öğe taşınan kaynak klasörler ve kök altındaki ataları en derinden başlayarak: yalnız `.DS_Store` (normal dosya) varsa o silinir; boşsa journal `rmdir` (path, pending) → `rmdir(2)` → done; boş değilse dokunulmaz. Kök ve kök dışı asla.
- Undoer: tüm `done` işlemler (`rmdir`, `move`, `mkdir`) **tek ters seq** sırasında: `rmdir` → klasörü yeniden oluştur (varsa dokunma) → `undo done`; `move` → bugünkü kurallar; `mkdir` → bugünkü boş klasör kaldırma.
- Recovery: pending `rmdir` → yol yoksa done, varsa failed.

- [ ] **Step 1: Failing tests** — `removesFoldersEmptiedByTheRunAndUndoRecreatesThem` (`Rastgele/a.pdf` dağıtılır, ayar açık → `Rastgele` yok; undo → `Rastgele/a.pdf` geri, klasör var); `dsStoreOnlyFolderIsRemovedAndNotRestored` (`.DS_Store` geri gelmez); `(.tags(.edgeCase)) preexistingEmptyFoldersAndRootAreLeftAlone` (önceden boş `Bos/` kalır; kök kalır); `nonEmptyFolderIsKept` (taşınmayan bir dosya kalan klasör kalır); `settingOffKeepsEmptiedFolders`; `recoveryResolvesPendingRmdir`.
- [ ] **Step 2–4: RED → Implement → GREEN**
- [ ] **Step 5: Commit** — `feat(core): optional removal of folders emptied by a run; undo replays in one reverse order`

---

### Task 7: CLI

**Files:** Modify `Sources/trimly/Output.swift`, `SetCommand.swift`, `scripts/smoke.sh`

**Interfaces — Produces:** Satırlarda ad yerine `relativePath`; klasör satırında `[dağıt]` / `[bütün tut · N öğe]`; kapsanan öğeler listelenmez, istatistikte "Kapsanan: N"; `plan.truncated` ise "Uyarı: 5.000 öğe sınırına ulaşıldı; daha derine inilmedi."; `trimly set <plan> <item> --mode keep|distribute`.

- [ ] **Step 1:** smoke'a ek senaryo: `Rastgele/{a.pdf,b.jpg}` + `Tatil/{1,2}.jpg`; `plan --no-llm` çıktısında `Rastgele/b.jpg` ve `[dağıt]`; `set … --mode keep` sonrası `apply --yes`; `Gorseller/Rastgele` veya ilgili hedef var; `undo` sonrası ağaç eski hali.
- [ ] **Step 2: RED** (`zsh scripts/smoke.sh` başarısız) · **Step 3: Implement** · **Step 4: GREEN** (`SMOKE OK`)
- [ ] **Step 5: Commit** — `feat(cli): nested items, folder modes and --mode`

---

### Task 8: Uygulama

**Files:** Create `App/TrimlyApp/Plan/PendingGroup.swift`, `FolderModePicker.swift`; Modify `PlanSession.swift`, `PendingSection.swift`, `ItemRow.swift`, `Settings/TargetTab.swift`; Test `App/TrimlyAppTests/PlanSessionNestedTests.swift`

**Interfaces — Produces:**
- `struct PendingGroup: Identifiable { let id: String /* "root" veya klasör kimliği */; let folder: PlanItem?; let title: String /* "Üst seviye" veya relativePath */; let items: [PlanItem] }`
- `PlanSession.pendingGroups: [PendingGroup]` — üst seviye karar bekleyenler "root" grubunda; `distribute` (karışık) bir klasörün altındaki karar bekleyenler o klasörün grubunda (klasör satırı başlık). `pendingItems` = gruplardaki tüm öğeler (mevcut testler korunur).
- `PlanSession.setFolderMode(_ mode: FolderMode, for itemID: String)` (edit yoluyla); `scanNotice: String?` — `plan.truncated` ise "5.000 öğe sınırına ulaşıldı; daha derindeki öğeler taranmadı."
- `readyGroups`/seçim kapsanmışları içermez.
- `ItemRow`: `depth > 0` ise ad yerine `relativePath`; klasör satırında `FolderModePicker` (Dağıt / Bütün tut; modu sabit klasörlerde yok); `keep` klasörde "N öğe · M kritik" detayı (kapsanan torunlardan).
- Ayarlar › Hedef: "Tarama derinliği" `Stepper` (1…5), "Yalnızca boş kalan klasörleri kaldır" `Toggle`.

- [ ] **Step 1: Failing tests** — `mixedFolderItemsAreGroupedUnderTheirFolder`; `folderModeSwitchMovesRowsBetweenSections` (keep → çocuklar gruplardan ve readyGroups'tan kaybolur, klasör satırı kalır); `coveredItemsAreNotSelectable`; `(.tags(.edgeCase)) truncatedScanShowsNotice` (Planner'a `limit` geçilemediği için `Plan.truncated = true` kaydedilmiş planı `latestReady` ile yükleyen kurulum).
- [ ] **Step 2–4: RED → Implement → GREEN** (xcodebuild test)
- [ ] **Step 5: Commit** — `feat(app): nested plan groups, folder mode picker, depth settings`

---

### Task 9: Elle doğrulama ve gerçek veri ölçümü

- [ ] **Step 1:** Geçici iç içe klasörle (`launchctl setenv TRIMLY_DATA_DIR …`, `open -a <build> "trimly://…"`) AX dökümüyle: grup başlığı, mod seçici, göreli yollar; mod değiştirme sonrası bölümler; apply → boş klasör kaldırma (ayar açık) → Geri Al. Pencerelere tıklamadan önce kullanıcıya haber verilir.
- [ ] **Step 2:** Gerçek `~/Downloads` ve `~/Desktop` üzerinde **yalnız** `trimly plan --no-llm` (derinlik 3): süre, öğe sayısı, `truncated`, kapsanan/etkin/karışık klasör sayıları, merkezi arşiv modunda göç önerisi sayısı → rapora (`docs/superpowers/reports/2026-11-21-phase3a-verification.md`), adsız.
- [ ] **Step 3: Commit** — `docs: phase 3a verification report`
