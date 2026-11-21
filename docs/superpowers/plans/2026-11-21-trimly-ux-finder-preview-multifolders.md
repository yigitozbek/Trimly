# Trimly UX — Finder, çoklu klasör, Etiketler, önizleme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının Masaüstü / İndirilenler / Belgeler’i seçerek taraması; Finder’da doğru öğeleri görmesi; Etiketler ayarına gidebilmesi; satırda Quick Look önizleme; `recentMinutes` yüzünden “hiç düzelmedi” hissinin giderilmesi.

**Architecture:** Mevcut tek-kök `Plan` / `WindowGroup` korunur. Başlangıçta çoklu klasör seçimi her kök için ayrı plan penceresi açar. Finder `NSWorkspace.activateFileViewerSelecting`. Ayarlar sekmesi `@AppStorage` / environment ile seçilir. Önizleme `QLPreviewPanel` (AppKit köprüsü). Banner, `PlanSession.skippedGroups` üzerinden “Son N dakikada…” sayısını gösterir.

**Tech Stack:** Swift 6.4, SwiftUI (macOS 14+), AppKit, QuickLookUI, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-ux-finder-preview-multifolders.md`

## Global Constraints

- Tüm disk / ev dizini taraması yok; yalnız kullanıcı seçtiği klasörler.
- Tek planda birden fazla kök yok (çoklu pencere = çoklu plan).
- Silme / üzerine yazma / toplu çöp yok; `apply` / `trash` onaysız çalışmaz.
- Quick Look salt okunur; LLM’e içerik göndermez.
- Arayüz metinleri Türkçe; proje skill’leri; `swift test` + `xcodegen` / `xcodebuild test`.

## Review Focus

1. **Yalnız kök seçiliyken Finder** → taşınan yoksa kök açılır; taşınan varsa hedef URL’ler seçilir (test: ResultSheet / helper).
2. **Çöpteki öğe satır Finder** → kaynak yoksa no-op veya “bulunamadı”; crash yok.
3. **Etiketler deep-link** → Settings açılınca Etiketler sekmesi görünür (test veya UI smoke).
4. **Space önizleme** → dosya yok / klasör → panel açılmaz, crash yok.
5. **recent banner** → 0 atlanan → banner yok; çoğunluk recent → Hariç tutma kısayolu görünür.

---

## File Structure

```
App/TrimlyApp/
  Start/ StartView.swift · FolderPickerChips.swift (yeni)
  Plan/  ResultSheet.swift · ItemRow.swift · PlanContent.swift · PlanSession.swift
         RecentSkipBanner.swift (yeni) · QuickLookPresenter.swift (yeni)
  Settings/ SettingsTab.swift (yeni) · SettingsView.swift · SettingsTabs.swift
  Shared/ FinderReveal.swift (yeni)
App/TrimlyAppTests/ FinderRevealTests.swift · PlanSessionRecentBannerTests.swift · StartFolderSelectionTests.swift (gerekirse)
```

---

### Task 1: FinderReveal + ResultSheet / satır

**Files:** Create `Shared/FinderReveal.swift`; Modify `ResultSheet.swift`, `ItemRow.swift`, `TrashRow.swift`; Test `FinderRevealTests.swift`

**Produces:**
- `enum FinderReveal { static func urls(_ urls: [URL]); static func item(_ item: PlanItem) }` — var olan yolları filtreler; boşsa no-op.
- ResultSheet: `lastRun` sonrası journal/plan’dan taşınan hedefler yoksa `session.root`; `trashed` run’larda kök veya atlanan yok.
- ItemRow / TrashRow: bağlam menüsü veya küçük düğme “Finder'da göster” → kaynak (çöpteyse dosya yoksa no-op).

- [ ] **Step 1:** Failing tests — `revealsExistingURLsOnly`; `itemUsesSourceWhenPresent`.
- [ ] **Step 2–4:** RED → implement → GREEN
- [ ] **Step 5: Commit** — `fix(app): reveal moved files and row in Finder`

---

### Task 2: Ayarlar sekme deep-link (Etiketler)

**Files:** Create `Settings/SettingsTab.swift`; Modify `SettingsView.swift`, `SettingsTabs.swift`, `PlanContent`/`ItemRow` (etiket notundan aç), `StartView` isteğe bağlı

**Produces:**
- `enum SettingsTab: String` — naming, target, tags, trash, model, ignore
- `SettingsView(initialTab:)` / `@AppStorage("settingsTab")` + `TabView(selection:)`
- `SettingsOpener.open(.tags)` — `NSApp.sendAction(Selector(("showSettingsWindow:"))…)` veya `SettingsLink` + storage yazımı
- Plan’da `existingTags` / etiket satırından “Etiket eşlemeleri…” → `.tags`

- [ ] **Step 1:** Unit/test — `SettingsTab` raw values stable; opener sets storage to tags before open
- [ ] **Step 2–4**
- [ ] **Step 5: Commit** — `feat(app): open Settings on Tags tab`

---

### Task 3: Quick Look önizleme

**Files:** Create `Plan/QuickLookPresenter.swift`; Modify `PlanContent.swift` / `ItemRow.swift`

**Produces:**
- `QuickLookPresenter` — seçili `URL` için `QLPreviewPanel`; `QLPreviewPanelDataSource`
- Plan listesinde seçim → Space (`.onKeyPress(.space)` veya `commands`) → presenter
- Klasör / eksik dosya → panel yok

- [ ] **Step 1:** Test veya derlenebilir spike + `previewURL(for:)` helper test
- [ ] **Step 2–4**
- [ ] **Step 5: Commit** — `feat(app): Quick Look preview for selected plan row`

---

### Task 4: Başlangıç çoklu klasör seçimi

**Files:** Create `Start/FolderPickerChips.swift`; Modify `StartView.swift`; Test seçim modeli

**Produces:**
- Chip’ler: Masaüstü, İndirilenler, Belgeler (toggle); “Seçilenleri aç” birden fazla `openWindow(id: "plan", value:)`
- Mevcut tek tık kısayolları ve “Klasör seç…” kalır
- Hiçbiri seçili değilken “Seçilenleri aç” disabled

- [ ] **Step 1:** `selectedFolders` model testi
- [ ] **Step 2–4**
- [ ] **Step 5: Commit** — `feat(app): multi-select Desktop/Downloads/Documents on start`

---

### Task 5: recentMinutes banner + Hariç tutma kısayolu

**Files:** Create `Plan/RecentSkipBanner.swift`; Modify `PlanSession.swift`, `PlanContent.swift`

**Produces:**
- `PlanSession.recentSkipCount` — `skippedGroups` içinde `Son \(settings.recentMinutes) dakikada` ile başlayan grup
- Banner: “Son N dakikada K öğe atlandı (yeni indirmeler).” + düğme → Settings `.ignore`
- Banner yalnız `K > 0`; `K` etkin (non-covered) öğelerin ≥ %80’iyse ek cümle: “Neredeyse hepsi yeni; eşiği düşürmeyi düşünün.”

- [ ] **Step 1:** `PlanSessionRecentBannerTests` — count + eşik metni
- [ ] **Step 2–4**
- [ ] **Step 5: Commit** — `feat(app): explain recentMinutes skips on plan`

---

### Task 6: Doğrulama

- [ ] `swift test`; `cd App && xcodegen generate && xcodebuild … test`
- [ ] Elle (mümkünse): çoklu açılış, Finder, Space QL, Etiketler sekmesi, recent banner
- [ ] Commit — `docs: UX finder/preview/multifolders note` (kısa rapor isteğe bağlı)
