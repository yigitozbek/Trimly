# Trimly Faz 3c — Çöp Adayları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gereksiz dosyaları (eski kurulum, bayat yarım indirme, özdeş kopya, boş, geçici) çöp adayı olarak işaretlemek; kullanıcının bunları **tek tek** Çöp Kutusu'na göndermesi ve journal'lı geri alması.

**Architecture:** `TrashDetector` plan oluştururken her etkin dosyaya en fazla bir `TrashReason` yazar. Adaylar normal sınıflandırılır ama `approved = false` gelir. `Executor.trash(planID:itemID:)` tek öğelik bir run açar (`JournalOp.trash`), plan `ready` kalır; `Undoer` ters sırada Çöp'ten geri getirir. Toplu çöp API'si yok.

**Tech Stack:** Swift 6.4, TrimlyCore, CryptoKit (SHA-256), FileManager.trashItem, swift-argument-parser, SwiftUI (macOS 14+), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-phase3-nested-tags-trash-design.md` (§5.1 çöp alanları, §5.7, §5.8–5.9 çöp kısımları; 3a/3b bu planın dışında)

## Global Constraints

- `Plan.currentEngineVersion = 5`.
- Çöp: yalnız `FileManager.trashItem(at:resultingItemURL:)`; kalıcı silme / Çöp boşaltma yok; **toplu çöp yok** (çekirdek API, CLI, arayüz).
- Varsayılanlar: `trashInstallerAgeDays = 30`, `trashPartialDownloadAgeDays = 1`, `trashDuplicates = true`, `trashEmptyFiles = true`, `trashTempFiles = true`.
- **Asla aday olmaz:** kritik öğeler, klasörler, proje alt ağaçları (skip/proje), `covered` öğeler.
- Taze yarım indirme (yaş < `trashPartialDownloadAgeDays`) bugünkü gibi `skipped "Yarım indirme"`; bayat olanlar aday olur (atlanmaz).
- Journal `trash`: `from` = kaynak, `to` = Çöp'teki yol. Geri alma dosyayı `from`'a taşır; Çöp'te yoksa "Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)".
- Her çöp atma kendi run'ı; Geçmiş'te "Çöp: \<ad\>"; plan `ready` kalır, öğeye `trashedRunID`.
- Mevcut güvenlik: silme/üzerine yazma yok, `DataLock`, kritik otomatik/toplu onaylanmaz, içerik LLM'e gitmez.
- Proje skill'leri; arayüz/CLI Türkçe; gerçek klasörlerde yalnız `plan` (geçici `--data-dir`).
- Komutlar: `swift test`; app `xcodegen` + `xcodebuild … test`; `zsh scripts/smoke.sh`.

## Review Focus

1. **Kritik dosya (kimlik.pdf)** → çöp adayı olmaz; `Executor.trash` reddeder (test: Task 2 `criticalNeverBecomesTrashCandidate`, Task 4 `trashRejectsCritical`).
2. **Taze `.crdownload`** → hâlâ `skipped "Yarım indirme"`; bayat olan (≥ `trashPartialDownloadAgeDays`) aday `stalePartialDownload` (test: Task 2 `freshPartialStillSkipped`, `stalePartialIsTrashCandidate`).
3. **Kopya grubu: `fatura.pdf` + `fatura (1).pdf` aynı SHA** → orijinal kısa/eksiz ad; `(1)` aday `duplicate(of:)` (test: Task 2 `duplicatePicksOriginalByName`).
4. **Çöp boşaltılmışken Geri Al** → dosya geri gelmez; `skipped` sebebi "Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)" (test: Task 4 `undoReportsEmptiedTrash`).
5. **`keep` klasörün içindeki dosya** → `covered`; çöp adayı olmaz ve `trash` reddeder (test: Task 2 `coveredItemNeverTrashCandidate`).

---

## File Structure

```
Sources/TrimlyCore/
  Model/ TrashReason.swift (yeni) · PlanItem.swift (+ trashReason, trashedRunID) · Settings.swift (+ trash*)
         Plan.swift (engine 5)
  Rules/ IgnoreRules.swift (taze yarım indirme; bayatı atlama)
  Planning/ TrashDetector.swift (yeni) · Planner.swift (detector sonrası; aday onay=false)
  Execution/ JournalOp.swift (+ trash) · Executor.swift (+ trash(planID:itemID:))
             Undoer.swift (+ trash geri alma) · Recovery.swift (+ trash)
             RunLog.swift · RunInfo.swift (+ trashed, title) · RunSummary.swift (+ trashed)
Sources/trimly/ TrashCommand.swift (yeni) · Trimly.swift · Output.swift · RunsCommand.swift
App/TrimlyApp/ Plan/TrashSection.swift, TrashRow.swift (yeni) · PlanContent.swift · PlanSession.swift
               Runs/RunRow.swift · Settings/TrashTab.swift (yeni) · SettingsTabs.swift
```

---

### Task 1: Model — TrashReason, ayarlar, journal, engine 5

**Files:** Create `Sources/TrimlyCore/Model/TrashReason.swift`; Modify `PlanItem.swift`, `Settings.swift`, `Plan.swift`, `JournalOp.swift`, `RunSummary.swift`, `RunInfo.swift`; Test `Tests/TrimlyCoreTests/Model/PlanItemDecodingTests.swift`, `SettingsTests.swift`

**Interfaces — Produces:**
- `enum TrashReason: Codable, Equatable, Sendable { case oldInstaller(days: Int); case stalePartialDownload; case duplicate(of: String); case emptyFile; case tempFile }` + `var label: String` (TR: "30 günden eski kurulum dosyası", "Bayat yarım indirme", "`fatura.pdf` ile aynı içerik", "Boş dosya", "Geçici dosya").
- `PlanItem.trashReason: TrashReason?`, `trashedRunID: String?` (`decodeIfPresent`).
- Settings: `trashInstallerAgeDays = 30`, `trashPartialDownloadAgeDays = 1`, `trashDuplicates/EmptyFiles/TempFiles = true` (`decodeIfPresent`).
- `JournalOp.trash`; `Plan.currentEngineVersion = 5`.
- `RunSummary.trashed: Int = 0`; `RunInfo.trashed: Int = 0`, `title: String? = nil` (çöp run'larında "Çöp: ad").

- [ ] **Step 1: Failing tests** — `engineVersionIsFive`; `defaultsMatchSpec` trash alanları; `decodesPhase3bItemWithoutTrashFields` → `trashReason`/`trashedRunID` nil.
- [ ] **Step 2–4: RED → Implement → GREEN** (`swift test` + app derlenir)
- [ ] **Step 5: Commit** — `feat(core): trash reason fields, trash settings, engine 5`

---

### Task 2: TrashDetector + IgnoreRules yarım indirme ayrımı

**Files:** Create `Sources/TrimlyCore/Planning/TrashDetector.swift`; Modify `IgnoreRules.swift`, `Planner.swift`; Test `Tests/TrimlyCoreTests/Planning/TrashDetectorTests.swift`

**Interfaces — Produces:**
- `IgnoreRules.skipReason`: yarım indirme uzantılarında yaş < `trashPartialDownloadAgeDays` ise "Yarım indirme"; aksi (bayat) `nil` (aday değerlendirmesine bırak).
- Yaş hesabı: `spotlightDateAdded ?? createdAt ?? modifiedAt`; yoksa taze sayma (güvenli taraf: atla / aday yapma — Ruling: tarihsiz yarım indirme atlanır).
- `enum TrashDetector { static func apply(_ plan: inout Plan, files: [FileItem], settings: Settings, now: Date) }` — yalnız `covered == false`, `status != .skipped`, `kind != .folder`, `critical == false` dosyalar. Sıra (ilk eşleşen): temp → empty → stalePartial → oldInstaller → duplicate (ayar kapalıysa o kural yok).
- Uzantılar: installer `{dmg,pkg,mpkg,iso,exe,msi}`; partial IgnoreRules ile aynı; temp: uzantı `tmp` veya ad `~$…` / `Thumbs.db`.
- Duplicate: boyut > 0 grupları; her dosya için akışlı SHA-256 (`CryptoKit`); orijinal = kopya eki (` (N)`, ` kopya`, ` copy`, case-insensitive) olmayan en kısa ad, eşitse en eski (`spotlightDateAdded ?? createdAt ?? modifiedAt`); diğerlerine `duplicate(of: original.relativePath)`.
- Planner: sınıflandırma + TargetAssigner sonrası `TrashDetector.apply`; `trashReason != nil` → `approved = false` (status hazır kalsa da).
- Adaylar `apply` ile taşınmaz (`approved == false`); kullanıcı isterse tek tek onaylayabilir (organize) veya çöpe atar.

- [ ] **Step 1: Failing tests** (geçici kök, sabit `now`):
  - `oldInstallerIsCandidate` — 40 günlük `.dmg` → `oldInstaller(days: 30)`.
  - `freshPartialStillSkipped` / `stalePartialIsTrashCandidate`.
  - `duplicatePicksOriginalByName` — aynı içerik `a.pdf` + `a (1).pdf` → yalnızca `(1)` aday, `of: "a.pdf"`.
  - `emptyAndTemp` — 0 bayt; `~$book.docx`; `Thumbs.db`.
  - `(.tags(.edgeCase)) criticalNeverBecomesTrashCandidate` — `kimlik.pdf`.
  - `(.tags(.edgeCase)) coveredItemNeverTrashCandidate` — keep klasör çocuğu.
  - `disabledRulesProduceNoCandidates` — tüm trash toggle false → hiç aday yok.
- [ ] **Step 2–4: RED → Implement → GREEN**
- [ ] **Step 5: Commit** — `feat(core): TrashDetector and age-aware partial downloads`

---

### Task 3: Executor.trash + Undoer + Recovery + RunLog

**Files:** Modify `Executor.swift`, `Undoer.swift`, `Recovery.swift`, `RunLog.swift`; Test `Tests/TrimlyCoreTests/Execution/TrashExecutionTests.swift`

**Interfaces — Produces:**
- `Executor.trash(planID:itemID:) async throws -> RunSummary` (`@concurrent`, `DataLock`): plan `ready` (aksi `alreadyApplied` / `notReady`); öğe var, `trashReason != nil`, `trashedRunID == nil`, `critical == false`, `covered == false`, `kind != .folder`; parmak izi; `trashItem` → journal `trash` pending (`from`,`to`) → done; plan kaydı `trashedRunID` (plan state `ready`); `RunSummary(trashed: 1, …)`; header `at` + isteğe `title` RunLog'da "Çöp: \(name)".
- Hata: aday değil / kritik / kapsanan → `ExecutionError` (Türkçe `UserMessage`); kaynak yok/değişmiş → failed/skipped özeti.
- Undoer: `trash` done ops ters sırada; `to` yoksa skip "Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)"; `from` doluysa skip; aksi `to`→`from` move. `UndoSummary` mevcut alanlar yeterli (`restored`).
- Recovery: pending `trash` → `to` varsa done, yoksa failed; undo-of-trash → `from` varsa done.
- `RunLog`: `trashed` = done trash sayısı; `undone` = tüm done move **ve** tag **ve** trash geri alınmış; `title` trash-only run'da "Çöp: …".

- [ ] **Step 1: Failing tests**:
  - `trashMovesToTrashAndUndoRestores` — aday → trash → kaynak yok, Çöp'te var; undo → kaynakta.
  - `(.tags(.edgeCase)) undoReportsEmptiedTrash` — trash sonrası `to` silinir → undo skipped o mesajla.
  - `(.tags(.edgeCase)) trashRejectsCritical` / `trashRejectsNonCandidate`.
  - `trashRunIsListedSeparately` — `RunLog.list` title "Çöp: …", `trashed == 1`, `undone == false` → undo sonrası true.
  - `recoveryResolvesPendingTrash`.
- [ ] **Step 2–4: RED → Implement → GREEN**
- [ ] **Step 5: Commit** — `feat(core): single-item trash with journaled undo`

---

### Task 4: CLI

**Files:** Create `Sources/trimly/TrashCommand.swift`; Modify `Trimly.swift`, `Output.swift`, `RunsCommand.swift`; `scripts/smoke.sh`

**Interfaces — Produces:**
- `trimly trash <plan> <item> [--yes]` — onay ister; özet `Çöp'e atılan: 1`.
- Plan satırı: `trashReason != nil` iken notta sebep etiketi; çöpe atılmışsa "çöpte".
- Runs: title varsa onu yaz; `çöp N` sayacı.
- Smoke: bayat `.dmg` (mtime eski) → plan aday; `trash --yes`; dosya kökte yok; `undo`; dosya geri.

- [ ] **Step 1:** smoke senaryosu (RED) · **Step 2–4** · **Step 5: Commit** — `feat(cli): trimly trash single item`

---

### Task 5: Uygulama

**Files:** Create `TrashSection.swift`, `TrashRow.swift`, `TrashTab.swift`; Modify `PlanContent.swift`, `PlanSession.swift`, `RunRow.swift`, `SettingsTabs.swift`; Test `App/TrimlyAppTests/PlanSessionTrashTests.swift`

**Interfaces — Produces:**
- `PlanSession.trashCandidates` (`trashReason != nil && trashedRunID == nil`); `trash(_:)` / `undoTrash(runID:)` session API.
- `TrashSection` / `TrashRow`: sebep + "Çöp Kutusu'na at"; atılmışsa "Çöp Kutusu'nda · Geri Al". **Toplu düğme yok.**
- Ayarlar › **Çöp** sekmesi: beş kural Toggle + iki Stepper (gün).
- `RunRow`: title veya "Çöp: …"; `trashed > 0` iken geri alma etkin.

- [ ] **Step 1: Failing tests** — `trashCandidateAppearsInSection`; `trashAndUndoFromSession`.
- [ ] **Step 2–4: RED → Implement → GREEN** (xcodebuild test)
- [ ] **Step 5: Commit** — `feat(app): trash candidates section and settings`

---

### Task 6: Elle doğrulama ve ölçüm

- [ ] **Step 1:** Geçici klasör: eski dmg, kopya çifti, boş dosya; tek tek çöp + geri al; Çöp boşaltılmış gibi silinince mesaj. Arayüz tıklamadan önce haber.
- [ ] **Step 2:** Gerçek `~/Downloads` / `~/Desktop` yalnız `plan --no-llm` (geçici data-dir): aday sayıları sebebe göre → `docs/superpowers/reports/2026-11-21-phase3c-verification.md` (adsız). Planlar silinir.
- [ ] **Step 3: Commit** — `docs: phase 3c verification report`
