# Trimly Faz 3b — Finder Etiketleri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mevcut Finder etiketlerinden kesin kategori çıkarmak (etiket eşlemeleriyle), taşınan öğelere kategori etiketi eklemek ve hiçbir şey taşımayan "Sadece etiketle" modu; hepsi journal'lı ve geri alınabilir.

**Architecture:** Tarayıcı `tagNames` okur; `RuleEngine` ad kalıplarından önce `TagRule`'a bakar. `TargetAssigner` hedefin yanında `tagsToAdd` hesaplar (`tagOnly`'de yalnız onu). Executor taşımadan sonra (veya `tagOnly`'de tek başına) journal `tag` yazar; `Undoer` journal'ı **tek ters seq sırasında** oynatır (3a'nın üç geçişi yerine), `tag` geri alınırken `previousTags` geri yazılır.

**Tech Stack:** Swift 6.4, TrimlyCore, swift-argument-parser, SwiftUI (macOS 14+), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-phase3-nested-tags-trash-design.md` (§5.1 etiket alanları, §5.6, §5.8–5.9 etiket kısımları; 3c bu planın dışında)

## Global Constraints

- `Plan.currentEngineVersion = 4`.
- Etiketler yalnız `URLResourceValues.tagNames` ile okunur/yazılır; **mevcut etiketler korunur** (yalnızca eklenir), büyük/küçük harf duyarsız tekrar eklenmez.
- Eklenen etiket: kategorinin `tag.value(settings.categoryLanguage)` değeri (ör. "Fatura").
- Varsayılanlar: `addCategoryTags = true`, `tagMappings = [:]` (etiket → kategori kimliği), `TargetMode.tagOnly` yeni durum.
- Journal `tag`: `path` = işlem anındaki son yol, `previousTags`, `tags` (yazılan tam liste). Geri alma `previousTags`'i aynen geri yazar, taşımayı geri almadan önce (tek ters sıra).
- Mevcut güvenlik ilkeleri her yolda: silme/üzerine yazma yok, `DataLock`, kritik öğe otomatik/toplu onaylanmaz, içeriği LLM'e gitmez; kapsanan öğe tek başına işlem görmez.
- Proje skill'leri (`swift-concurrency-pro`, `swift-testing-pro`, `swiftui-pro`), her tür kendi dosyasında; arayüz/CLI metinleri Türkçe. Gerçek klasörlerde yalnız `plan` (salt okunur, geçici `--data-dir`).
- Komutlar: `swift test`; `cd App && xcodegen generate && cd .. && xcodebuild -project App/Trimly.xcodeproj -scheme TrimlyApp -destination 'platform=macOS' -derivedDataPath .build/xcode test`; `zsh scripts/smoke.sh`.

## Review Focus

1. **Kategori etiketi zaten var (farklı harf: "fatura")** → ikinci kez eklenmez; `tagOnly`'de öğe `skipped "Zaten etiketli"` (test: Task 3 `existingTagIsNotAddedTwice`).
2. **Kullanıcı uygulamadan sonra etiketleri değiştirdi, sonra Geri Al** → Trimly kullanıcının yeni etiketlerini silmez; etiket adımı "Etiketler sonradan değişmiş" ile atlanır, taşıma yine geri alınır (test: Task 4 `undoKeepsTagsTheUserChangedSince`).
3. **Hassas kategoriye eşlenen etiket ("Kimlik")** → öğe kritik olur, otomatik onaylanmaz (test: Task 2 `sensitiveTagMakesItemCritical`).
4. **Elle düzenlenmiş `tagMappings` var olmayan bir kategoriye işaret ediyor** → yok sayılır, çökme yok, sıradaki kural çalışır (test: Task 2 `mappingToUnknownCategoryIsIgnored`).
5. **Yalnız etiket ekleyen (taşımasız) bir run** → Geçmiş'te ve `trimly undo`'da geri alınabilir görünür (taşıması olmadığı için "geri alınmış" sayılmaz) (test: Task 4 `tagOnlyRunIsUndoable`).

---

## File Structure

```
Sources/TrimlyCore/
  Model/ FileItem.swift (+ finderTags) · PlanItem.swift (+ existingTags, tagsToAdd, hasAction) · Settings.swift (+ addCategoryTags, tagMappings)
         TargetMode.swift (+ tagOnly) · Plan.swift (engine 4)
  Scan/FolderScanner.swift (+ tagNamesKey)
  Rules/TagRule.swift (yeni) · RuleMatch.swift (+ tag) · RuleEngine.swift (etiket önce)
  Naming/TargetAssigner.swift (tagsToAdd, tagOnly, "Zaten etiketli") · TargetResolver.swift (tagOnly durumu)
  Planning/Planner.swift (etiketli klasör LLM'siz; hassas etiket → kritik) · PlanEditor.swift (onay: hasAction)
  Execution/FinderTags.swift (yeni) · JournalOp.swift (+ tag) · JournalEntry.swift (+ tags, previousTags)
            Executor.swift (etiket yazma) · Undoer.swift (tek ters sıra) · Recovery.swift (+ tag) · RunLog.swift, RunInfo.swift, RunSummary.swift, UndoSummary.swift (+ tagged)
Sources/trimly/ Output.swift · ApplyCommand.swift · RunsCommand.swift · UndoCommand.swift
App/TrimlyApp/ Plan/ItemRow.swift, ApplySheet.swift, ApplySummary.swift, ResultSheet.swift, PlanSession.swift · Runs/RunRow.swift
               Settings/TargetTab.swift · TagsTab.swift (yeni) · TagMappingRow.swift (yeni) · SettingsTabs.swift
```

---

### Task 1: Model alanları ve etiket okuma

**Files:** yukarıdaki Model dosyaları, `FolderScanner.swift`, `JournalOp.swift`, `JournalEntry.swift`, `RunSummary.swift`, `UndoSummary.swift`, `RunInfo.swift`; Test `Tests/TrimlyCoreTests/Model/PlanItemDecodingTests.swift`, `Tests/TrimlyCoreTests/Scan/FolderScannerTests.swift`, `Tests/TrimlyCoreTests/Model/SettingsTests.swift`; Fixture `TestFS.setTags(_ tags: [String], on url: URL) throws`

**Interfaces — Produces:**
- `FileItem.finderTags: [String]` (init'te varsayılan `[]`); `FolderScanner` `.tagNamesKey` okur.
- `PlanItem.existingTags: [String]`, `PlanItem.tagsToAdd: [String]` (decode varsayılanı `[]`); `public var hasAction: Bool { target != nil || tagsToAdd.isEmpty == false }`.
- `Settings.addCategoryTags = true`, `Settings.tagMappings: [String: String] = [:]` (`decodeIfPresent`); `TargetMode.tagOnly`.
- `JournalOp.tag`; `JournalEntry.tags: [String]?`, `JournalEntry.previousTags: [String]?` (init'e sona varsayılanlı).
- `RunSummary.tagged: Int`, `UndoSummary.restoredTags: Int`, `RunInfo.tagged: Int` (init'lerde varsayılan 0).
- `Plan.currentEngineVersion = 4`. `TargetMode` üzerindeki her `switch` derlenir (`TargetResolver`'da `.tagOnly` tabanı kök; hiç kullanılmaz).

- [ ] **Step 1: Failing tests** — `defaultsMatchSpec`'e `addCategoryTags && tagMappings.isEmpty`; `decodesPhase3aItemWithoutTagFields` (`existingTags`/`tagsToAdd` anahtarları silinmiş JSON → ikisi de `[]`); `engineVersionIsFour` (eski `engineVersionIsThree`'nin yerine); `scannerReadsFinderTags` (dosyaya `["Proje X", "Fatura"]` yazılır → `items[0].finderTags == ["Proje X", "Fatura"]`).
- [ ] **Step 2: RED** · **Step 3: Implement** · **Step 4: GREEN** (`swift test` + app derlenir)
- [ ] **Step 5: Commit** — `feat(core): Finder tag fields, tag-only target mode, tag journal op`

---

### Task 2: Etiket kuralı

**Files:** Create `Sources/TrimlyCore/Rules/TagRule.swift`; Modify `RuleMatch.swift`, `RuleEngine.swift`, `Planning/Planner.swift`; Test `Tests/TrimlyCoreTests/Rules/TagRuleTests.swift`

**Interfaces — Produces:**
- `RuleMatch.tag: String?` (eşleşen etiket; init'te varsayılan nil).
- `enum TagRule { static func match(_ tags: [String], settings: Settings) -> (categoryID: String, tag: String)? }` — etiketler **kendi sıralarıyla** denenir, ilk eşleşen kazanır. Bir etiket için önce `tagMappings` (anahtarlar `Normalizer.ascii(_).lowercased()` ile karşılaştırılır; değer `settings.category(id:)` ile var olmalı, yoksa yok sayılır), sonra kategorilerin `folder.tr/en` ve `tag.tr/en` değerleri (aynı normalleştirmeyle).
- `RuleEngine.match`: ilk iş `TagRule` → `RuleMatch(categoryID:, strength: .decisive, descriptionHint: nil, tag:)`; yoksa bugünkü akış. `RuleEngine` artık `settings`'i saklar.
- Planner: `rule.tag != nil` ise `item.reason = "Etiket: \(tag)"`; kategori `sensitiveCategoryIDs` içindeyse `item.critical = true`. Etiketli **klasörler** LLM'e gitmez: kural kategorisiyle `applyFallback` (`review/.folder`, elle onay).

- [ ] **Step 1: Failing tests** (`FileItem.stub`'a `tags:` parametresi):
  - `tagWinsOverNamePatterns` — `Screenshot 2025-03-14 at 10.22.31.png`, etiket `["Fatura"]` → `invoices`, `.decisive`, `tag == "Fatura"`.
  - `mappingIsCaseAndAccentInsensitive` — `tagMappings = ["Vergi": "invoices"]`, etiket `["VERGİ"]` → `invoices`; etiket `["sözleşme"]` (eşleme yok) → `contracts` (klasör/etiket adı).
  - `firstMatchingTagWins` — `["Kırmızı", "Sözleşme", "Fatura"]` → `contracts`.
  - `(.tags(.edgeCase)) mappingToUnknownCategoryIsIgnored` — `["Vergi": "yok-boyle"]`, etiket `["Vergi"]`, ad `download.pdf` → bugünkü kural (`documents`, `tag == nil`).
  - `(.tags(.edgeCase)) sensitiveTagMakesItemCritical` — Planner: `a.pdf` etiket `["Kimlik"]` → `categoryID == "officialDocs"`, `critical`, `approved == false`, `reason == "Etiket: Kimlik"`.
  - `taggedFolderSkipsTheLLM` — etiketli klasör `Proje` (`["Fatura"]`), mock LLM → istek yok, `categoryID == "invoices"`, `status == .review`.
- [ ] **Step 2–4: RED → Implement → GREEN** (`swift test`)
- [ ] **Step 5: Commit** — `feat(core): Finder tags decide the category before name rules`

---

### Task 3: Eklenecek etiketler ve "Sadece etiketle"

**Files:** Modify `Naming/TargetAssigner.swift`, `Planning/PlanEditor.swift`, `Planning/Planner.swift` (öğeye `existingTags = file.finderTags`); Test `Tests/TrimlyCoreTests/Naming/TagAssignmentTests.swift`

**Interfaces — Produces:**
- `TargetAssigner.assign` her etkin (kapsanmamış, atlanmamış, kategorili) öğe için:
  - `inPlace`/`central`: hedef bugünkü gibi; `addCategoryTags` açık ve hedef varsa `tagsToAdd = [kategori etiketi]` (mevcut etiketlerde harf duyarsız yoksa), aksi `[]`.
  - `tagOnly`: `target = nil`; `tagsToAdd` aynı kurala göre (ayar kapalı olsa da — modun anlamı bu). `tagsToAdd` boş kalan öğe `skipped "Zaten etiketli"`. Dağıtılan klasörlere etiket yok.
- `PlanEditor.bulkApprove` / `setApproval`: `item.target != nil` koşulu → `item.hasAction`.

- [ ] **Step 1: Failing tests** (plan stub'larıyla):
  - `moveModeAddsCategoryTag` — invoices öğesi → `tagsToAdd == ["Fatura"]`; `addCategoryTags = false` → `[]`.
  - `(.tags(.edgeCase)) existingTagIsNotAddedTwice` — `existingTags = ["fatura"]` → `tagsToAdd == []`; `tagOnly`'de `skipReason == "Zaten etiketli"`.
  - `tagOnlyHasNoTargetsButIsApprovable` — `tagOnly`: `target == nil`, `tagsToAdd == ["Fatura"]`, `PlanEditor.setApproval(...) == 1`.
  - `coveredItemsGetNoTags` — `keep` klasörün çocuğu → `tagsToAdd == []`; klasörün kendisi `["Gorsel"]` (`tagOnly`).
- [ ] **Step 2–4: RED → Implement → GREEN**
- [ ] **Step 5: Commit** — `feat(core): tags to add, tag-only mode`

---

### Task 4: Etiket yazma, tek ters sırada geri alma

**Files:** Create `Sources/TrimlyCore/Execution/FinderTags.swift`; Modify `Executor.swift`, `Undoer.swift`, `Recovery.swift`, `RunLog.swift`; Test `Tests/TrimlyCoreTests/Execution/TagExecutionTests.swift`

**Interfaces — Produces:**
- `enum FinderTags { static func read(_ url: URL) -> [String]; static func write(_ tags: [String], to url: URL) throws }` (önbellek: okumadan önce `removeCachedResourceValue(forKey: .tagNamesKey)`).
- Executor: onaylı ve `hasAction` öğe için: hedef varsa bugünkü taşıma; ardından `tagsToAdd` varsa son yolda: `previous = FinderTags.read`, `tags = previous + eksikler` (harf duyarsız); eksik yoksa işlem yok; varsa journal `tag` pending (`path`, `previousTags`, `tags`) → yaz → done / failed (`failed`'a "Etiket eklenemedi: …"; taşıma geri alınabilir kalır). `tagOnly`'de taşıma yok, parmak izi kontrolü aynen. `RunSummary.tagged` = başarılı etiket işlemleri.
- Undoer: `done` durumlu ve geri alınmamış tüm işlemler (`rmdir`, `tag`, `move`, `mkdir`) **tek döngüde, seq'e göre tersten**; her işlem bugünkü kuralıyla. `tag`: yolda dosya yoksa "Dosya bulunamadı"; mevcut etiketler (küme olarak) journal'daki `tags` değilse "Etiketler sonradan değişmiş" ile atlanır; aksi `previousTags` yazılır. `UndoSummary.restoredTags`.
- Recovery: pending `tag` → yoldaki etiketler (küme) `tags` ise done, değilse failed.
- `RunLog`: `RunInfo.tagged` = done `tag` sayısı; `undone` = tüm done `move` **ve** `tag` işlemleri geri alınmış (hiç işlem yoksa true kalır).

- [ ] **Step 1: Failing tests** (geçici klasör, `PlannerFixture`):
  - `moveAddsTagAndUndoRestoresPreviousTags` — `fatura.pdf` etiket `["Proje X"]` → apply: hedefte `["Proje X", "Fatura"]`, `summary.tagged == 1`; undo: kaynakta `["Proje X"]`.
  - `tagOnlyTagsInPlaceAndUndoes` — `tagOnly`: dosya yerinde, `["Fatura"]`; undo → `[]`.
  - `(.tags(.edgeCase)) undoKeepsTagsTheUserChangedSince` — apply sonrası etiketler `["Benim"]` yapılır; undo → dosya kaynağa döner, etiketler `["Benim"]`, `skipped` içinde "Etiketler sonradan değişmiş".
  - `(.tags(.edgeCase)) tagOnlyRunIsUndoable` — `tagOnly` apply → `RunLog.list(...)[0].undone == false`, `.tagged == 1`; `Undoer.undo(runID: nil)` bu run'ı geri alır.
  - `recoveryResolvesPendingTag` — pending `tag`: etiketler yazılmış → done; yazılmamış → failed.
  - Mevcut `UndoerTests` ve `EmptyFolderTests` değişmeden geçer (tek ters sıra eski journal'ları da doğru oynatır).
- [ ] **Step 2–4: RED → Implement → GREEN**
- [ ] **Step 5: Commit** — `feat(core): write category tags, undo replays the journal in one reverse order`

---

### Task 5: CLI

**Files:** Modify `Sources/trimly/Output.swift`, `ApplyCommand.swift`, `RunsCommand.swift`, `UndoCommand.swift`, `scripts/smoke.sh`

**Interfaces — Produces:** Hedef sütunu: `tagOnly` → `＋ Fatura etiketi`; taşıma + etiket → `Faturalar/… ＋Fatura`; mevcut etiketler not sütununda `etiket: Proje X`. Apply: `Taşınan: N · Etiketlenen: M · …`; runs: `taşınan N  etiket M`; undo: `geri yüklenen N · etiketi geri alınan M · …`.

- [ ] **Step 1:** smoke'a senaryo: `settings.json`'da `"targetMode":"tagOnly"` olan ayrı veri dizini; `fatura-ocak.pdf`; `plan` çıktısında `＋ Fatura etiketi`; `apply --yes`; dosya yerinde ve `xattr -px com.apple.metadata:_kMDItemUserTags … | xxd -r -p | plutil -p -` çıktısında `Fatura`; `undo`; etiket özniteliği yok veya `Fatura` içermiyor.
- [ ] **Step 2: RED** · **Step 3: Implement** · **Step 4: GREEN** (`SMOKE OK`)
- [ ] **Step 5: Commit** — `feat(cli): show and count tags`

---

### Task 6: Uygulama

**Files:** Create `App/TrimlyApp/Settings/TagsTab.swift`, `TagMappingRow.swift`; Modify `ItemRow.swift`, `ApplySummary.swift`, `ApplySheet.swift`, `ResultSheet.swift`, `PlanSession.swift`, `Runs/RunRow.swift`, `Settings/TargetTab.swift`, `SettingsTabs.swift`; Test `App/TrimlyAppTests/PlanSessionTagTests.swift`

**Interfaces — Produces:**
- `PlanSession`: "Tümünü seç", grup onayı ve `approvedItems` `target != nil` yerine `hasAction`; `ApplySummary.isTagOnly: Bool` (plan modu `tagOnly`).
- `ItemRow` hedef satırı: `tagOnly` → "＋ Fatura etiketi"; taşıma + etiket → "→ Faturalar/… · ＋ Fatura etiketi"; `existingTags` boş değilse ayrıntı satırına "Etiketler: …".
- `ApplySheet`: `isTagOnly` → başlık "N öğeye etiket eklenecek", açıklama "Hiçbir dosya taşınmaz; Geri Al eklenen etiketleri kaldırır."; aksi bugünkü metin (+ ayar açıksa "Taşınan dosyalara kategori etiketi eklenir.").
- `ResultSheet` ve `RunRow`: "etiketlenen N" (> 0 ise); `RunRow` geri alma düğmesi `moved == 0 && tagged == 0` iken pasif.
- Ayarlar › Hedef: mod seçicisine "Taşıma; yalnızca kategori etiketi ekle" (`tagOnly`); "Taşınan dosyalara kategori etiketi ekle" `Toggle` (`tagOnly`'de gizli). Yeni **Etiketler** sekmesi (`tag` simgesi): eşleme listesi — her satırda etiket metni ve kategori `Picker`; "Ekle" / satır kaldırma; boş etiket kaydedilmez.

- [ ] **Step 1: Failing tests** — `tagOnlyPlanIsApprovableAndSummarized` (`tagOnly` ayarı; hazır öğeler onaylı, `applySummary.isTagOnly`, `count == hazır öğe sayısı`); `tagOnlyApplyAndUndoRestoreTags` (session apply → dosya yerinde etiketli; session undo → etiket yok); `selectAllUsesTagActions` (`tagOnly`'de karar bekleyen bir dosya "Tümünü seç" ile onaylanır).
- [ ] **Step 2–4: RED → Implement → GREEN** (xcodebuild test)
- [ ] **Step 5: Commit** — `feat(app): tag-only mode, tag previews, tag mappings settings`

---

### Task 7: Elle doğrulama ve gerçek veri ölçümü

- [ ] **Step 1:** Geçici klasörde (geçici `TRIMLY_DATA_DIR`): taşıma + etiket ve `tagOnly`; Finder'da etiketlerin görünmesi (`mdls -name kMDItemUserTags` / `xattr`); Geri Al; Ayarlar › Etiketler'de eşleme ekleyip yeniden tarayınca kategorinin değişmesi. Arayüze tıklamadan önce kullanıcıya haber verilir.
- [ ] **Step 2:** Gerçek `~/Downloads` ve `~/Desktop` üzerinde yalnız `trimly plan --no-llm` (geçici `--data-dir`, kullanıcı ayarlarının kopyası): Finder etiketi olan öğe sayısı, etiketle karar verilen sayı, `tagOnly` modunda etiket eklenecek sayı → `docs/superpowers/reports/2026-11-21-phase3b-verification.md` (adsız). Ölçüm planları sonra silinir.
- [ ] **Step 3: Commit** — `docs: phase 3b verification report`
