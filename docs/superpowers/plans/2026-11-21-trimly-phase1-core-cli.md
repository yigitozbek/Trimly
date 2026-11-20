# Trimly Faz 1 — Çekirdek + CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `TrimlyCore` Swift paketi (tarama, hariç tutma, kritik tespit, kural motoru, Ollama JSON sınıflandırıcı, adlandırma/çakışma, checkpoint'li plan, fsync JSONL journal, undo) ve onu kullanan `trimly` CLI; ileride TrimlyApp aynı kütüphaneyi doğrudan çağıracak.

**Architecture:** Tek SwiftPM paketi: `TrimlyCore` (library) + `trimly` (executable, swift-argument-parser) + `TrimlyCoreTests` (Swift Testing). Hat: `Scanner → IgnoreRules → CriticalDetector/RuleEngine → (LLM1) → DescriptionSanitizer → Normalizer → DateResolver → NamingTemplate → TargetResolver (çakışma) → Plan`. Uygulama `Executor` ile journal'a yazarak taşır, `Undoer` journal'ı ters oynatır.

**Tech Stack:** Swift 6.4 (Xcode 27.2), swift-tools-version 6.2, macOS 14+, Foundation, CoreServices (MDItem), PDFKit, AppKit (`NSAttributedString` docx/rtf), CryptoKit, Swift Testing, swift-argument-parser ≥ 1.5.0, Ollama 0.40.16 HTTP API.

**Spec:** `docs/superpowers/specs/2026-11-21-trimly-design.md`

## Global Constraints

- `swift-tools-version: 6.2` (swift-concurrency-pro: "Target Swift 6.2 or later"; kullanıcı iskeletindeki 6.0'dan tek fark), Swift 6 language mode (strict concurrency), `platforms: [.macOS(.v14)]`.
- **Proje skill'leri** `.claude/skills/` altında: `swift-concurrency-pro`, `swift-testing-pro`, `swiftui-pro` (Faz 2). Kod yazarken ve review'da uygulanır. Bu planı bağlayan kuralları:
  - Her tür kendi dosyasında; dosya adı = tür adı (swiftui-pro). Aşağıdaki "Files" listeleri ana dosyaları adlandırır; Interfaces'teki her tür kendi `<TürAdı>.swift` dosyasına gider (aynı klasörde).
  - `@unchecked Sendable` ve `nonisolated(unsafe)` yok; değer tipleri ve actor tercih edilir.
  - Dosya/PDF okuyan ağır async API'ler (`Planner.makePlan`, `Planner.review`) `@concurrent` işaretlenir; böylece Faz 2'de MainActor'dan çağrılsalar da UI'ı bloklamazlar.
  - Testler: suite = `struct`, gereksiz `@Suite` yok (yalnızca trait/tag gerekiyorsa); `#expect`/`#require` içinde `!` yok (`== false` kullanılır); tekrar eden durumlar parametreli test; `#expect(throws:)` belirli hata değeriyle (asla `Error.self`); ön koşullar `#require`.
  - Test klasörleri üretim klasörlerini aynalar (`Tests/TrimlyCoreTests/<Alan>/<Tür>Tests.swift`); yardımcılar `Tests/TrimlyCoreTests/Fixtures/`.
  - Ağ testleri canlı ağa çıkmaz: HTTP katmanı protokolle enjekte edilir (`HTTPTransport`), testler `.networking` tag'i taşır; Review Focus testleri `.edgeCase` tag'i taşır.
- Tek dış bağımlılık `swift-argument-parser` (`from: "1.5.0"`), yalnızca `trimly` target'ında. `TrimlyCore` yalnızca sistem framework'leri kullanır.
- Kullanıcı dosyası **asla silinmez, asla üzerine yazılmaz**; taşıma yalnızca `FileManager.moveItem`. Tek silme istisnası: undo sırasında Trimly'nin oluşturduğu boş klasörün (ve içindeki tek `.DS_Store`'un) kaldırılması.
- Kritik öğenin içeriği hiçbir aşamada `ClassificationRequest.contentPreview`'a girmez; kritik öğenin `approved` alanını hiçbir otomatik adım `true` yapamaz.
- Veri dizini varsayılanı `~/Library/Application Support/Trimly/` → `settings.json`, `plans/<planId>.json`, `runs/<runId>.jsonl`; her komut/testte `DataDirectory` ile değiştirilebilir.
- Varsayılanlar (spec §5.10): `namingPreset = dateCategoryDescription`, `categoryLanguage = tr`, `targetMode = inPlace`, `archiveRoot = "~/Documents/Arsiv"`, `yearSubfolders = false`, `llmEnabled = true`, `providerURL = "http://localhost:11434"`, `stage1Model = "qwen3:4b"`, `stage2Model = "ministral-3:14b"`, `confidenceThreshold = 0.75`, `batchSize = 10`, `contentPreview = true`, `timeoutSeconds = 60`, `keepAlive = "2m"`, `recentMinutes = 60`.
- Ollama isteği: `POST /api/chat`, `stream: false`, `think: false`, `options: {temperature: 0, num_ctx: 4096}`, `keep_alive` = ayar, `format` = JSON şema; 1 yeniden deneme.
- İçerik önizleme: 1. aşama 1.500 karakter / PDF 1 sayfa; 2. aşama 4.000 karakter / PDF 2 sayfa.
- Açıklama ≤ 50 karakter, `reason` ≤ 160 karakter (kodda kesilir).
- Sıra sabit: `DescriptionSanitizer → Normalizer → NamingTemplate` ad üretir, **sonra** `TargetResolver` büyük/küçük harf duyarsız `_2, _3` çakışma kontrolü yapar.
- JSON: plan/settings `prettyPrinted + sortedKeys`, tarihler ISO8601; journal satırı tek satır compact JSON. Değişiklik kontrolü **tek yerden**: `SourceFingerprint.matches(_:)` — dosyada boyut eşit ve mtime farkı < 1 sn (ISO8601 kesirli saniyeyi düşürür); dizinlerde (`size == nil`: klasör/paket) yalnızca varlık kontrolü (Finder'ın `.DS_Store` yazması klasör mtime'ını değiştirir). Executor ve Undoer başka karşılaştırma yazmaz.
- Kullanıcıya görünen metinler Türkçe.
- Testler gerçek `~/Desktop`/`~/Downloads`'a dokunmaz. Gerçek veri yalnızca Task 15'te ve yalnızca `plan` (salt okunur) ile; gerçek veride `apply` kullanıcı açık onayı olmadan çalışmaz.
- Proje kökü: `/Users/yigitozbek/Projects/Trimly`. Tüm komutlar buradan.

## Review Focus

1. **Yeni indirilmiş ama sunucu mtime'ı eski dosya** → "son 60 dk" kuralı `max(modifiedAt, createdAt, spotlightDateAdded)` ile atlamalı (test: Task 5 `recentUsesNewestOfDates`).
2. **Bileşik uzantılar** (`.tar.gz`) yeni adda ve çakışma sonekinde korunmalı (test: Task 3 `compoundExtension`, Task 9 `compoundExtensionSuffix`).
3. **Kullanıcı Finder'da açtığı için içinde yalnızca `.DS_Store` olan Trimly klasörü** undo'da yine kaldırılmalı (test: Task 13 `undoTreatsDSStoreOnlyFolderAsEmpty`).
4. **Düzenlenmiş klasörde tekrar `plan`**: kategori klasörleri atlanmalı, onaylanacak öğe çıkmamalı (test: Task 12 `rerunAfterApplyFindsNothing`).
5. **Yalnızca emoji/sembolden oluşan ad** (`🔥🔥.png`) → açıklama zinciri boş kalırsa `Dosya` (tr) / `File` (en) (test: Task 10 `emojiOnlyNameFallsBack`).

---

## File Structure

```
Package.swift
.gitignore                                   # .build/, .swiftpm/, *.xcodeproj/xcuserdata
Sources/TrimlyCore/
  Model/FileItem.swift                       # EntryKind, SourceFingerprint, FileItem (kullanıcı iskeleti + isLink)
  Model/Category.swift                       # Language, LocalizedText, Category, DefaultCategories
  Model/Settings.swift                       # NamingPreset, TargetMode, Settings (+ decodeIfPresent)
  Model/Plan.swift                           # ItemStatus, DecidedBy, ReviewReason, PlanState, PlanItem, Plan, PlanError
  Model/DataDirectory.swift                  # DataDirectory, SettingsStore, JSONCoding
  Naming/KnownExtensions.swift
  Naming/Normalizer.swift
  Naming/DescriptionSanitizer.swift
  Naming/DateResolver.swift
  Naming/NamingTemplate.swift
  Naming/TargetResolver.swift                # TargetResolver + TargetAssigner
  Scan/Scanner.swift                         # Scanner, ScanError
  Scan/MetadataReader.swift                  # SpotlightInfo, MetadataReader
  Scan/ContentPreview.swift
  Rules/IgnoreRules.swift
  Rules/CriticalDetector.swift
  Rules/RuleEngine.swift                     # RuleStrength, RuleMatch, RuleEngine
  Rules/DefaultRules.swift                   # extensionMap, ad kalıpları
  LLM/LLMProvider.swift                      # protocol (ClassificationRequest/Result, ProviderHealth, LLMError kendi dosyalarında)
  LLM/HTTPTransport.swift                    # protocol + URLSessionTransport
  LLM/ResponseSchema.swift
  LLM/PromptBuilder.swift
  LLM/OllamaProvider.swift
  Planning/PlanStore.swift
  Planning/Planner.swift                     # PlanProgress, PlanStats, Planner (makePlan, review, stats)
  Planning/PlanEditor.swift
  Execution/Journal.swift                    # JournalOp, JournalState, JournalEntry, Journal
  Execution/Executor.swift                   # RunSummary, SkippedEntry, ExecutionError, Executor
  Execution/Recovery.swift
  Execution/Undoer.swift                     # UndoSummary, UndoError, Undoer, RunInfo, RunLog
Sources/trimly/
  Trimly.swift                               # @main AsyncParsableCommand + ortak seçenekler
  PlanCommands.swift                         # plan, review, set, approve
  RunCommands.swift                          # apply, undo, runs, settings
  Output.swift                               # tablo/istatistik biçimleme
Tests/TrimlyCoreTests/
  Fixtures/  TestFS.swift  FileItem+Stub.swift  Tags.swift  MockLLMProvider.swift  RecordingTransport.swift  PlannerFixture.swift
  Model/     SettingsTests.swift
  Naming/    NormalizerTests.swift DescriptionSanitizerTests.swift DateResolverTests.swift NamingTemplateTests.swift TargetResolverTests.swift
  Scan/      ScannerTests.swift ContentPreviewTests.swift
  Rules/     IgnoreRulesTests.swift CriticalDetectorTests.swift RuleEngineTests.swift
  LLM/       OllamaProviderTests.swift PromptBuilderTests.swift
  Planning/  PlannerTests.swift ReviewAndEditorTests.swift
  Execution/ JournalTests.swift ExecutorTests.swift UndoerTests.swift
```

---

### Task 1: Paket iskeleti, modeller, ayarlar, veri dizini

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/TrimlyCore/Model/*.swift`, `Sources/trimly/Trimly.swift` (yer tutucu `@main`, `--version` basar), `Tests/TrimlyCoreTests/Fixtures/TestFS.swift`, `Fixtures/FileItem+Stub.swift`, `Fixtures/Tags.swift` (`extension Tag { @Tag static var networking: Self; @Tag static var fileSystem: Self; @Tag static var edgeCase: Self }`)
- Test: `Tests/TrimlyCoreTests/Model/SettingsTests.swift`, `Tests/TrimlyCoreTests/Model/SourceFingerprintTests.swift`

**Interfaces:**
- Produces:
  - `Package.swift` ve `FileItem.swift`: kullanıcının verdiği iskelet **birebir**, tek fark `FileItem`'a son alan olarak `public let isLink: Bool` (init'te `isLink: Bool = false`, son parametre).
  - `enum Language: String, Codable, Sendable { case tr, en }`; `struct LocalizedText: Codable, Equatable, Sendable { var tr: String; var en: String; func value(_: Language) -> String }`
  - `struct Category: Codable, Equatable, Sendable, Identifiable { let id: String; var folder: LocalizedText; var tag: LocalizedText }`
  - `enum DefaultCategories { static let all: [Category] }` — 22 kategori, sıra ve değerler aşağıdaki tabloda.
  - `enum NamingPreset: String, Codable, CaseIterable, Sendable { case dateCategoryDescription, categoryDescription, dateDescription, originalNormalized, keepOriginal }`
  - `enum TargetMode: String, Codable, Sendable { case inPlace, central }`
  - `struct Settings: Codable, Equatable, Sendable` — Global Constraints'teki varsayılanlar + `ignoreHidden = true`, `ignoreApps = true`, `projectMarkers`, `projectFolderNames`, `ignoreGlobs`, `criticalExtensions`, `criticalKeywords`, `categories = DefaultCategories.all`. Eksik JSON anahtarları varsayılana düşer (custom `init(from:)` + `decodeIfPresent`). Yardımcılar: `func category(id: String) -> Category?`, `func category(forFolderName: String) -> Category?` (tr/en, büyük/küçük harf duyarsız), `func categoryTerms(_ c: Category) -> [String]` (folder+tag, tr+en), `var allCategoryFolderNames: Set<String>` (küçük harf, tr+en).
  - `enum ItemStatus: String, Codable, Sendable { case ready, review, skipped, critical }`; `enum DecidedBy: String, Codable, Sendable { case rule, llm1, llm2, manual }`; `enum ReviewReason: String, Codable, Sendable, CaseIterable { case lowConfidence, llmError, weakRuleNoLLM, folder }`; `enum PlanState: String, Codable, Sendable { case inProgress, ready, applied }`
  - `struct PlanItem: Codable, Equatable, Sendable, Identifiable { let id: String; let name: String; let source: URL; let kind: EntryKind; let fileExtension: String; let resolvedDate: Date; var categoryID: String?; var description: String?; var target: URL?; var confidence: Double?; var reason: String?; var decidedBy: DecidedBy?; var status: ItemStatus; var reviewReason: ReviewReason?; var skipReason: String?; var critical: Bool; var approved: Bool; var classified: Bool; let sourceFingerprint: SourceFingerprint }`
  - `struct Plan: Codable, Equatable, Sendable { let id: String; let root: URL; let createdAt: Date; var state: PlanState; var appliedRunID: String?; var settingsSnapshot: Settings; var items: [PlanItem] }`
  - `enum PlanError: Error, Equatable { case notFound(String), itemNotFound(String), unknownCategory(String), alreadyApplied, notReady }`
  - `struct DataDirectory: Sendable { let root: URL; static var `default`: DataDirectory; var settingsURL, plansURL, runsURL: URL; func ensureExists() throws }`
  - `enum SettingsStore { static func load(from: DataDirectory) throws -> Settings; static func save(_: Settings, to: DataDirectory) throws }` — dosya yoksa varsayılan döner (dosya yazmaz).
  - `enum JSONCoding { static let encoder: JSONEncoder; static let decoder: JSONDecoder }` (ISO8601, pretty, sortedKeys).
  - `extension SourceFingerprint { static func read(from url: URL) -> SourceFingerprint? /* yoksa nil; dizinde size nil */; func matches(_ current: SourceFingerprint) -> Bool /* size nil → true; aksi size == && abs(Δmtime) < 1.0 */ }` (`Model/SourceFingerprint+Matching.swift`)
  - Test destek: `enum TestFS { static func tempDir() throws -> URL /* resolvingSymlinksInPath: /var → /private/var */; @discardableResult static func file(_ name: String, in: URL, contents: String = "x", modified: Date = .twoDaysAgo, created: Date? = .twoDaysAgo) throws -> URL; @discardableResult static func folder(_ name: String, in: URL) throws -> URL }`, `extension Date { static var twoDaysAgo: Date }`, `extension FileItem { static func stub(_ name: String, kind: EntryKind = .file, modifiedAt: Date = .twoDaysAgo, createdAt: Date? = .twoDaysAgo, dateAdded: Date? = nil, contentCreation: Date? = nil, utType: String? = nil, histogram: [String: Int] = [:], isLink: Bool = false, url: URL? = nil) -> FileItem }` (uzantı: `(name as NSString).pathExtension.lowercased()`).

Varsayılan kategoriler (`id`: folder tr / tag tr / folder en / tag en):

| id | tr | en |
|---|---|---|
| screenshots | Ekran-Goruntuleri / Ekran-Goruntusu | Screenshots / Screenshot |
| screenRecordings | Ekran-Kayitlari / Ekran-Kaydi | Screen-Recordings / Screen-Recording |
| photos | Fotograflar / Fotograf | Photos / Photo |
| images | Gorseller / Gorsel | Images / Image |
| videos | Videolar / Video | Videos / Video |
| audio | Ses / Ses | Audio / Audio |
| documents | Belgeler / Belge | Documents / Document |
| invoices | Faturalar / Fatura | Invoices / Invoice |
| contracts | Sozlesmeler / Sozlesme | Contracts / Contract |
| officialDocs | Resmi-Evrak / Evrak | Official-Documents / Official |
| health | Saglik / Saglik | Health / Health |
| books | Kitaplar-Makaleler / Kitap | Books-Papers / Book |
| spreadsheets | Tablolar / Tablo | Spreadsheets / Spreadsheet |
| presentations | Sunumlar / Sunum | Presentations / Presentation |
| data | Veri / Veri | Data / Data |
| code | Kod / Kod | Code / Code |
| design | Tasarim / Tasarim | Design / Design |
| archives | Arsivler / Arsiv | Archives / Archive |
| installers | Kurulum-Dosyalari / Kurulum | Installers / Installer |
| certificates | Sertifika-Anahtar / Sertifika | Certificates-Keys / Certificate |
| fonts | Yazi-Tipleri / Yazi-Tipi | Fonts / Font |
| other | Diger / Diger | Other / Other |

Liste varsayılanları:
- `projectMarkers`: `.git, package.json, node_modules, Package.swift, *.xcodeproj, Cargo.toml, pyproject.toml, go.mod, pom.xml, build.gradle, Gemfile, composer.json, .venv, venv, Pods`
- `projectFolderNames`: `build, dist, target, DerivedData, node_modules`
- `ignoreGlobs`: `*.photoslibrary, *.musiclibrary, *.fcpbundle, *.lrlibrary` (benim kararım: kütüphane paketleri taşınmamalı)
- `criticalExtensions`: `der, pem, cer, key, p12, pfx, mobileprovision, env, sql, sqlite, db, kdbx, udf`
- `criticalKeywords`: `kimlik, nufus, pasaport, tc, ehliyet, saglik, rapor, recete, tahlil, bordro, maas, iban, sifre, password, vekaletname`

- [ ] **Step 1: `git init` + `.gitignore`**

Run: `git init && printf ".build/\n.swiftpm/\nxcuserdata/\n" > .gitignore`
Expected: `Initialized empty Git repository`

- [ ] **Step 2: Write the failing tests**

```swift
struct SettingsTests {
    @Test func defaultsMatchSpec() {
        let s = Settings()
        #expect(s.stage1Model == "qwen3:4b" && s.stage2Model == "ministral-3:14b")
        #expect(s.confidenceThreshold == 0.75 && s.batchSize == 10 && s.recentMinutes == 60)
        #expect(s.namingPreset == .dateCategoryDescription && s.targetMode == .inPlace)
        #expect(s.archiveRoot == "~/Documents/Arsiv" && s.yearSubfolders == false)
        #expect(s.categories.count == 22 && s.categoryLanguage == .tr)
    }
    @Test func missingKeysFallBackToDefaults() throws {
        let s = try JSONCoding.decoder.decode(Settings.self, from: Data(#"{"stage1Model":"gemma3:4b"}"#.utf8))
        #expect(s.stage1Model == "gemma3:4b" && s.confidenceThreshold == 0.75)
    }
    @Test func storeReturnsDefaultsWhenMissingAndRoundTrips() throws {
        let dir = DataDirectory(root: try TestFS.tempDir())
        #expect(try SettingsStore.load(from: dir) == Settings())
        var s = Settings(); s.batchSize = 3
        try SettingsStore.save(s, to: dir)
        #expect(try SettingsStore.load(from: dir).batchSize == 3)
    }
    @Test func categoryLookup() {
        let s = Settings()
        #expect(s.category(id: "invoices")?.folder.tr == "Faturalar")
        #expect(s.category(id: "invoices")?.tag.en == "Invoice")
        #expect(s.category(forFolderName: "faturalar")?.id == "invoices")
        #expect(s.category(forFolderName: "Invoices")?.id == "invoices")
        #expect(s.allCategoryFolderNames.contains("ekran-goruntuleri"))
    }
    @Test func planRoundTripsThroughJSON() throws { /* 1 öğeli Plan → encode → decode → == */ }
}

struct SourceFingerprintTests {
    let base = Date(timeIntervalSince1970: 1_700_000_000.4)
    @Test func subSecondDriftMatches() { #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 5, modifiedAt: base.addingTimeInterval(0.6)))) }
    @Test func sizeOrSecondChangeDoesNotMatch() {
        #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 6, modifiedAt: base)) == false)
        #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 5, modifiedAt: base.addingTimeInterval(1.0))) == false)
    }
    @Test func directoriesOnlyNeedToExist() { #expect(SourceFingerprint(size: nil, modifiedAt: base).matches(.init(size: nil, modifiedAt: base.addingTimeInterval(500)))) }
    @Test func readReturnsNilForMissingFile() throws { #expect(SourceFingerprint.read(from: try TestFS.tempDir().appending(path: "yok")) == nil) }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter SettingsTests`
Expected: derleme hatası (`cannot find 'Settings' in scope`).

- [ ] **Step 4: Implement models, `DataDirectory`, `SettingsStore`, `JSONCoding`, test destek dosyaları**

- [ ] **Step 5: Run tests**

Run: `swift test --filter SettingsTests`
Expected: `Test run with 5 tests passed`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(core): package skeleton, models, settings store"
```

---

### Task 2: Normalizer + DescriptionSanitizer

**Files:**
- Create: `Sources/TrimlyCore/Naming/KnownExtensions.swift`, `Normalizer.swift`, `DescriptionSanitizer.swift`
- Test: `Tests/TrimlyCoreTests/Naming/NormalizerTests.swift`, `DescriptionSanitizerTests.swift`

**Interfaces:**
- Produces:
  - `enum KnownExtensions { static let all: Set<String> }` — Task 6 `DefaultRules.extensionMap` anahtarlarının tamamını + `tar` içerir.
  - `enum Normalizer { static func ascii(_: String) -> String; static func slug(_: String, maxLength: Int = 50) -> String; static func fullExtension(of name: String) -> String; static func normalizedFileName(_ name: String, isFolder: Bool) -> String }`
  - `enum DescriptionSanitizer { static let fillerWords: Set<String>; static func sanitize(_ raw: String, originalExtension: String, categoryTerms: [String]) -> String? }`
- Kurallar:
  - `ascii`: önce `ç→c ğ→g ı→i İ→I ö→o ş→s ü→u` (büyükler dahil), sonra NFD + combining işaretleri at (`applyingTransform(.stripDiacritics)`), ASCII dışı kalanı at.
  - `slug`: `ascii` → `[A-Za-z0-9]` dışı her şey ayırıcı → segmentlerin ilk harfi büyük (gerisi olduğu gibi) → `-` ile birleştir → `maxLength`'i aşarsa son tam segmentte kes; boş olabilir.
  - `fullExtension`: küçük harf; `tar.gz | tar.bz2 | tar.xz` bileşik; tek uzantı `^[a-z0-9]{1,10}$` değilse `""`.
  - `normalizedFileName`: klasörse tüm ad, değilse gövde → `slug(maxLength: 100)` + (`.` + `fullExtension`); slug boşsa orijinal ad döner.
  - `sanitize` sırası: (1) sondaki `.` + (orijinal uzantı veya `KnownExtensions`) tekrar tekrar at, (2) tarih kalıplarını at: `\d{4}[-_.]\d{2}[-_.]\d{2}`, `\d{2}[.-]\d{2}[.-]\d{4}`, `\b(19|20)\d{6}\b`, `(ay adı) \d{4}` ve `\d{4} (ay adı)` (TR: ocak…aralik ascii; EN: january…december), (3) `ascii` + küçük harfle token'lara böl, baştan ve sondan kategori terimi token dizilerini (her terim `-`'den bölünür) ve `fillerWords` (`dosya, file, belge, document, yeni, new, kopya, copy`) değişmeyene kadar at, (4) `slug(maxLength: 50)`, (5) sonuç < 2 karakter → `nil`.

- [ ] **Step 1: Write the failing tests**

```swift
struct NormalizerTests {
    @Test func asciiFoldsTurkish() { #expect(Normalizer.ascii("çğıİöşüÇĞÖŞÜ") == "cgiIosuCGOSU") }
    @Test func asciiFoldsNFD() {
        #expect(Normalizer.ascii("s\u{0327}u\u{0308}") == "su")
        #expect(Normalizer.ascii("café") == "cafe")
    }
    @Test func slugTitleCasesAndCleans() {
        #expect(Normalizer.slug("sözleşme v3 final") == "Sozlesme-V3-Final")
        #expect(Normalizer.slug("  Enerjisa__Ocak!! ") == "Enerjisa-Ocak")
        #expect(Normalizer.slug("İSTANBUL ışık") == "ISTANBUL-Isik")
        #expect(Normalizer.slug("a---b") == "A-B")
    }
    @Test func slugCutsAtWordBoundary() {
        let s = Normalizer.slug(String(repeating: "kelime ", count: 20))
        #expect(s.count <= 50)
        #expect(s.hasSuffix("-") == false)
        #expect(s.split(separator: "-").allSatisfy { $0 == "Kelime" })
    }
    @Test func slugOfSymbolsIsEmpty() { #expect(Normalizer.slug("🔥🔥 !!") == "") }
    @Test func fullExtension() {
        #expect(Normalizer.fullExtension(of: "backup.TAR.GZ") == "tar.gz")
        #expect(Normalizer.fullExtension(of: "a.pdf") == "pdf")
        #expect(Normalizer.fullExtension(of: "Makefile") == "")
        #expect(Normalizer.fullExtension(of: "v1.2 notes") == "")
    }
    @Test func normalizedFileName() {
        #expect(Normalizer.normalizedFileName("Proje Dosyaları (Eski).ZIP", isFolder: false) == "Proje-Dosyalari-Eski.zip")
        #expect(Normalizer.normalizedFileName("Kişisel v1.2", isFolder: true) == "Kisisel-V1-2")
    }
}

struct DescriptionSanitizerTests {
    let invoice = ["Faturalar", "Fatura", "Invoices", "Invoice"]
    @Test func stripsExtensionAndDate() {
        #expect(DescriptionSanitizer.sanitize("Enerjisa Ocak 2025-01-31.pdf", originalExtension: "pdf", categoryTerms: invoice) == "Enerjisa-Ocak")
    }
    @Test func stripsLeadingCategoryTerm() {
        #expect(DescriptionSanitizer.sanitize("Fatura - Turkcell Ekim", originalExtension: "pdf", categoryTerms: invoice) == "Turkcell-Ekim")
    }
    @Test func stripsMultiWordTerm() {
        let terms = ["Ekran-Goruntuleri", "Ekran-Goruntusu", "Screenshots", "Screenshot"]
        #expect(DescriptionSanitizer.sanitize("ekran görüntüsü toplantı notu", originalExtension: "png", categoryTerms: terms) == "Toplanti-Notu")
    }
    @Test(arguments: ["Kira 14.03.2025", "Kira 20250314", "Kira 2025_03_14", "Kira Mart 2025", "Kira march 2025", "2025-03-14 Kira"])
    func stripsDateFormats(_ raw: String) {
        #expect(DescriptionSanitizer.sanitize(raw, originalExtension: "pdf", categoryTerms: []) == "Kira")
    }
    @Test func stripsFillerAndKnownExtensions() {
        #expect(DescriptionSanitizer.sanitize("yeni dosya kopya.docx.pdf", originalExtension: "pdf", categoryTerms: []) == nil)
        #expect(DescriptionSanitizer.sanitize("Rapor copy.PDF", originalExtension: "pdf", categoryTerms: []) == "Rapor")
    }
    @Test func tooShortReturnsNil() {
        #expect(DescriptionSanitizer.sanitize("a", originalExtension: "txt", categoryTerms: []) == nil)
        #expect(DescriptionSanitizer.sanitize("2025-03-14", originalExtension: "png", categoryTerms: []) == nil)
    }
    @Test func capsAt50() {
        let s = DescriptionSanitizer.sanitize(String(repeating: "uzun kelime ", count: 10), originalExtension: "pdf", categoryTerms: [])
        #expect((s?.count ?? 99) <= 50)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "NormalizerTests|DescriptionSanitizerTests"` → derleme hatası.
- [ ] **Step 3: Implement** `KnownExtensions`, `Normalizer`, `DescriptionSanitizer` (kurallar yukarıda).
- [ ] **Step 4: Run tests** — aynı komut → tümü geçer.
- [ ] **Step 5: Commit** — `git commit -am "feat(core): normalizer and description sanitizer"` (yeni dosyalar için önce `git add -A`).

---

### Task 3: DateResolver + NamingTemplate

**Files:**
- Create: `Sources/TrimlyCore/Naming/DateResolver.swift`, `NamingTemplate.swift`
- Test: `Tests/TrimlyCoreTests/Naming/DateResolverTests.swift`, `NamingTemplateTests.swift`

**Interfaces:**
- Consumes: `FileItem`, `NamingPreset`, `Normalizer` (Task 1–2)
- Produces:
  - `enum DateResolver { static func dateFromName(_ name: String, calendar: Calendar = .current) -> Date?; static func resolve(_ item: FileItem, calendar: Calendar = .current) -> Date; static func dayString(_ date: Date, calendar: Calendar = .current) -> String /* "yyyy-MM-dd" */ }`
  - `enum NamingTemplate { static func fileName(preset: NamingPreset, day: String, categoryTag: String, description: String, originalName: String, fileExtension: String) -> String; static func folderName(preset: NamingPreset, originalName: String) -> String }`
- Kurallar: ad kalıpları `YYYY-MM-DD`, `YYYY_MM_DD`, `YYYYMMDD`, `DD.MM.YYYY`; yıl 1990…2100, geçerli ay/gün; yerel takvimde gece yarısı. `resolve` önceliği: ad → `spotlightContentCreationDate` → `createdAt` → `modifiedAt` → `Date()`. `fileExtension` boşsa nokta eklenmez; uzantı küçük harf. `folderName`: `keepOriginal` → orijinal, diğerleri → `Normalizer.normalizedFileName(isFolder: true)`.

- [ ] **Step 1: Write the failing tests**

```swift
struct DateResolverTests {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Istanbul")!; return c }
    func day(_ n: String) -> String? { DateResolver.dateFromName(n, calendar: cal).map { DateResolver.dayString($0, calendar: cal) } }
    @Test func dateFromNamePatterns() {
        #expect(day("Screenshot 2025-03-14 at 10.22.31.png") == "2025-03-14")
        #expect(day("IMG_20240812_101500.jpg") == "2024-08-12")
        #expect(day("fatura_14.03.2025.pdf") == "2025-03-14")
        #expect(day("scan 2025_01_02.pdf") == "2025-01-02")
        #expect(day("order-99999999.pdf") == nil)
        #expect(day("v2025-13-40.txt") == nil)
        #expect(day("12345678.pdf") == nil)
    }
    @Test func resolvePriority() {
        let d = { (s: String) in ISO8601DateFormatter().date(from: s)! }
        let all = FileItem.stub("rapor 2025-01-05.pdf", modifiedAt: d("2025-04-01T10:00:00Z"), createdAt: d("2025-03-01T10:00:00Z"), contentCreation: d("2025-02-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(all, calendar: cal), calendar: cal) == "2025-01-05")
        let noName = FileItem.stub("rapor.pdf", modifiedAt: d("2025-04-01T10:00:00Z"), createdAt: d("2025-03-01T10:00:00Z"), contentCreation: d("2025-02-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(noName, calendar: cal), calendar: cal) == "2025-02-01")
        let created = FileItem.stub("rapor.pdf", modifiedAt: d("2025-04-01T10:00:00Z"), createdAt: d("2025-03-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(created, calendar: cal), calendar: cal) == "2025-03-01")
    }
}

struct NamingTemplateTests {
    func name(_ p: NamingPreset, ext: String = "pdf", original: String = "download (3).PDF") -> String {
        NamingTemplate.fileName(preset: p, day: "2025-02-10", categoryTag: "Fatura", description: "Enerjisa-Ocak", originalName: original, fileExtension: ext)
    }
    @Test func presets() {
        #expect(name(.dateCategoryDescription) == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(name(.categoryDescription) == "Fatura_Enerjisa-Ocak.pdf")
        #expect(name(.dateDescription) == "2025-02-10_Enerjisa-Ocak.pdf")
        #expect(name(.originalNormalized) == "Download-3.pdf")
        #expect(name(.keepOriginal) == "download (3).PDF")
    }
    @Test(.tags(.edgeCase)) func compoundExtension() {
        #expect(NamingTemplate.fileName(preset: .dateCategoryDescription, day: "2025-02-10", categoryTag: "Arsiv", description: "Yedek", originalName: "yedek.tar.gz", fileExtension: "tar.gz") == "2025-02-10_Arsiv_Yedek.tar.gz")
    }
    @Test func noExtension() { #expect(name(.dateCategoryDescription, ext: "", original: "Makefile").hasSuffix("_Enerjisa-Ocak")) }
    @Test func folderNames() {
        #expect(NamingTemplate.folderName(preset: .dateCategoryDescription, originalName: "Tatil Fotoğrafları") == "Tatil-Fotograflari")
        #expect(NamingTemplate.folderName(preset: .keepOriginal, originalName: "Tatil Fotoğrafları") == "Tatil Fotoğrafları")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "DateResolverTests|NamingTemplateTests"` → derleme hatası.
- [ ] **Step 3: Implement** `DateResolver`, `NamingTemplate`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): date resolver and naming presets"`

---

### Task 4: Scanner + MetadataReader

**Files:**
- Create: `Sources/TrimlyCore/Scan/Scanner.swift`, `MetadataReader.swift`
- Test: `Tests/TrimlyCoreTests/Scan/ScannerTests.swift`

**Interfaces:**
- Consumes: `FileItem`, `Normalizer.fullExtension` (Task 1–2)
- Produces:
  - `enum ScanError: Error, Equatable { case notADirectory(URL) }`
  - `struct Scanner: Sendable { init(); func scan(root: URL) throws -> [FileItem] }` — yalnızca üst seviye, gizliler dahil (karar `IgnoreRules`'ta), ada göre `<` sıralı. Resource keys: `isDirectory, isPackage, isSymbolicLink, isAliasFile, fileSize, creationDate, contentModificationDate, contentType`. `kind`: paket → `.package`, klasör → `.folder`, aksi `.file`. `isLink = isSymbolicLink || isAliasFile`. `fileExtension = Normalizer.fullExtension(of: name)`. Klasörlerde (paket değil, link değil): gizli olmayan doğrudan çocukların ilk 20 adı (sıralı) ve tüm doğrudan çocukların uzantı histogramı (klasör çocuklar da uzantısıyla sayılır, ör. `xcodeproj`); boyut `nil`.
  - `struct SpotlightInfo: Sendable { var dateAdded: Date?; var whereFroms: [String]; var title: String?; var authors: [String]; var contentCreationDate: Date? }`; `enum MetadataReader { static func spotlight(for url: URL) -> SpotlightInfo }` — `MDItemCreateWithURL` + `kMDItemDateAdded, kMDItemWhereFroms, kMDItemTitle, kMDItemAuthors, kMDItemContentCreationDate`; indekslenmemişse boş değerler.

- [ ] **Step 1: Write the failing tests**

```swift
struct ScannerTests {
    @Test func scansTopLevelOnly() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("a.pdf", in: root); try TestFS.file(".hidden", in: root)
        let sub = try TestFS.folder("sub", in: root); try TestFS.file("inner.txt", in: sub)
        #expect(try Scanner().scan(root: root).map(\.name) == [".hidden", "a.pdf", "sub"])
    }
    @Test func fillsBasicMetadata() throws {
        let root = try TestFS.tempDir()
        try TestFS.file("Rapor.PDF", in: root, contents: "hello", modified: .twoDaysAgo)
        let item = try #require(try Scanner().scan(root: root).first)
        #expect(item.sizeBytes == 5 && item.fileExtension == "pdf" && item.kind == .file && item.isLink == false)
        let modified = try #require(item.modifiedAt)
        #expect(abs(modified.timeIntervalSince(.twoDaysAgo)) < 2)
        #expect(item.createdAt != nil)
    }
    @Test func folderSampleAndHistogram() throws {
        let root = try TestFS.tempDir(); let album = try TestFS.folder("Album", in: root)
        for i in 0..<22 { try TestFS.file("p\(i).jpg", in: album) }
        for i in 0..<3 { try TestFS.file("n\(i).txt", in: album) }
        try TestFS.file(".DS_Store", in: album)
        let item = try #require(try Scanner().scan(root: root).first)
        #expect(item.kind == .folder && item.folderSampleNames.count == 20)
        #expect(item.folderExtensionHistogram == ["jpg": 22, "txt": 3])
    }
    @Test func detectsPackageAndLink() throws {
        let root = try TestFS.tempDir()
        let app = try TestFS.folder("X.app", in: root); try TestFS.folder("Contents", in: app)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "link"), withDestinationURL: app)
        let items = try Scanner().scan(root: root)
        #expect(items.first { $0.name == "X.app" }?.kind == .package)
        #expect(items.first { $0.name == "link" }?.isLink == true)
    }
    @Test func rejectsNonDirectory() throws {
        let root = try TestFS.tempDir(); let f = try TestFS.file("a.txt", in: root)
        #expect(throws: ScanError.notADirectory(f)) { try Scanner().scan(root: f) }
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ScannerTests` → derleme hatası.
- [ ] **Step 3: Implement** `Scanner`, `MetadataReader` (Spotlight alanları `FileItem` init'ine geçirilir).
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): top-level scanner with spotlight metadata"`

---

### Task 5: IgnoreRules + CriticalDetector

**Files:**
- Create: `Sources/TrimlyCore/Rules/IgnoreRules.swift`, `CriticalDetector.swift`
- Test: `Tests/TrimlyCoreTests/Rules/IgnoreRulesTests.swift`, `CriticalDetectorTests.swift`

**Interfaces:**
- Consumes: `Settings`, `FileItem`, `Normalizer.ascii` (Task 1–2)
- Produces:
  - `struct IgnoreRules: Sendable { init(settings: Settings, now: Date); func skipReason(for item: FileItem) -> String? }`
  - `struct CriticalDetector: Sendable { init(settings: Settings); func isCritical(_ item: FileItem) -> Bool }`
- `skipReason` sırası ve **birebir** metinler: link → `"Kısayol veya sembolik bağ"`; ad `.DS_Store`/`.localized` → `"Sistem dosyası"`; `.` ile başlıyor ve `ignoreHidden` → `"Gizli dosya"`; `ignoreGlobs` eşleşmesi (`fnmatch`, `FNM_CASEFOLD`) → `"Hariç tutma listesi"`; uzantı `app` ve `ignoreApps` → `"Uygulama paketi"`; uzantı `crdownload|part|download|opdownload` → `"Yarım indirme"`; klasör + adı `allCategoryFolderNames` içinde → `"Trimly kategori klasörü"`; klasör + adı `projectFolderNames` içinde → `"Build/çıktı klasörü"`; klasör + `projectMarkers`'tan biri var (`*.ext` → histogramda `ext`; diğerleri `fileExists(url/marker)`) → `"Proje klasörü (<marker>)"`; `max(modifiedAt, createdAt, spotlightDateAdded) > now - recentMinutes` → `"Son <recentMinutes> dakikada değişti"`.
- `isCritical`: uzantının son bileşeni `criticalExtensions` içinde **veya** ad (`ascii`, küçük harf, alfanümerik olmayanlardan bölünmüş) token'larından biri bir anahtar kelimeyle eşleşiyor: anahtar ≥ 4 karakter → token onunla **başlar**; < 4 → token **eşittir**.

- [ ] **Step 1: Write the failing tests**

```swift
struct IgnoreRulesTests {
    let now = Date()
    var rules: IgnoreRules { IgnoreRules(settings: Settings(), now: now) }
    @Test func systemAndHidden() {
        #expect(rules.skipReason(for: .stub(".DS_Store")) == "Sistem dosyası")
        #expect(rules.skipReason(for: .stub(".localized")) == "Sistem dosyası")
        #expect(rules.skipReason(for: .stub(".secret")) == "Gizli dosya")
    }
    @Test func appsAndLinks() {
        #expect(rules.skipReason(for: .stub("Foo.app", kind: .package)) == "Uygulama paketi")
        #expect(rules.skipReason(for: .stub("kisayol", isLink: true)) == "Kısayol veya sembolik bağ")
    }
    @Test(arguments: ["big.zip.crdownload", "x.part", "y.download", "z.opdownload"])
    func partialDownloads(_ n: String) { #expect(rules.skipReason(for: .stub(n)) == "Yarım indirme") }
    @Test(.tags(.edgeCase)) func recentUsesNewestOfDates() {
        #expect(rules.skipReason(for: .stub("a.pdf", modifiedAt: now.addingTimeInterval(-600))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("b.pdf", dateAdded: now.addingTimeInterval(-300))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("c.pdf", createdAt: now.addingTimeInterval(-300))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("old.pdf")) == nil)
    }
    @Test func projectAndBuildFolders() throws {
        let root = try TestFS.tempDir()
        let p = try TestFS.folder("myproj", in: root); try TestFS.folder(".git", in: p)
        #expect(rules.skipReason(for: .stub("myproj", kind: .folder, url: p)) == "Proje klasörü (.git)")
        #expect(rules.skipReason(for: .stub("ios", kind: .folder, histogram: ["xcodeproj": 1])) == "Proje klasörü (*.xcodeproj)")
        #expect(rules.skipReason(for: .stub("node_modules", kind: .folder)) == "Build/çıktı klasörü")
        #expect(rules.skipReason(for: .stub("DerivedData", kind: .folder)) == "Build/çıktı klasörü")
    }
    @Test func categoryFoldersAndGlobs() {
        #expect(rules.skipReason(for: .stub("Faturalar", kind: .folder)) == "Trimly kategori klasörü")
        #expect(rules.skipReason(for: .stub("invoices", kind: .folder)) == "Trimly kategori klasörü")
        #expect(rules.skipReason(for: .stub("Faturalar")) == nil)
        #expect(rules.skipReason(for: .stub("Fotoğraflar.photoslibrary", kind: .package)) == "Hariç tutma listesi")
        var s = Settings(); s.ignoreGlobs = ["*.tmp"]
        #expect(IgnoreRules(settings: s, now: now).skipReason(for: .stub("x.TMP")) == "Hariç tutma listesi")
    }
}

struct CriticalDetectorTests {
    let d = CriticalDetector(settings: Settings())
    @Test(arguments: ["cert.der", "dump.SQL", "iade-talebi.udf", "ISTIRAHAT RAPORLARI.pdf", "kimlik_on.jpg", "TC_Kimlik.png", "Şifreler.txt", "maaş bordrosu.xlsx"])
    func critical(_ n: String) { #expect(d.isCritical(.stub(n))) }
    @Test(arguments: ["etc-notes.txt", "rapido.pdf", "tatil.jpg"])
    func notCritical(_ n: String) { #expect(d.isCritical(.stub(n)) == false) }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "IgnoreRulesTests|CriticalDetectorTests"` → derleme hatası.
- [ ] **Step 3: Implement** `IgnoreRules`, `CriticalDetector`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): ignore rules and critical detector"`

---

### Task 6: RuleEngine + DefaultRules

**Files:**
- Create: `Sources/TrimlyCore/Rules/RuleEngine.swift`, `DefaultRules.swift`
- Test: `Tests/TrimlyCoreTests/Rules/RuleEngineTests.swift`

**Interfaces:**
- Consumes: `Settings`, `FileItem`, `Normalizer.ascii`, `KnownExtensions` (Task 1–2)
- Produces:
  - `enum RuleStrength: String, Codable, Sendable { case decisive, weak }`
  - `struct RuleMatch: Equatable, Sendable { let categoryID: String; let strength: RuleStrength; let descriptionHint: String? }`
  - `struct RuleEngine: Sendable { init(settings: Settings); func match(_ item: FileItem) -> RuleMatch }` — opsiyonel değil; eşleşme yoksa `RuleMatch(categoryID: "other", strength: .weak, descriptionHint: nil)`.
  - `enum DefaultRules { static let extensionMap: [String: (categoryID: String, strength: RuleStrength)] }` — anahtar uzantının **son bileşeni** (`tar.gz` → `gz`).
- `extensionMap` (D = decisive, W = weak):
  - photos D: `heic heif dng cr2 nef arw raw` · images D: `png jpg jpeg gif webp bmp svg tiff tif`
  - videos D: `mp4 mov m4v avi mkv webm wmv flv 3gp` · audio D: `mp3 m4a wav aac flac ogg aiff aif opus`
  - archives: `zip` W; `rar 7z tar gz tgz bz2 xz` D · installers: `dmg pkg mpkg iso exe msi apk ipa` D; `jar` W
  - code D: `swift py js ts tsx jsx java kt c h cpp hpp m mm go rs rb php sh zsh html css scss ipynb`
  - data: `json csv`→(json data W, csv spreadsheets W); `geojson xml yaml yml plist tsv parquet sql sqlite db` D
  - spreadsheets D: `xlsx xls numbers ods` · presentations D: `pptx ppt odp`
  - documents W: `pdf doc docx txt md rtf pages odt` · design D: `psd pxd sketch fig ai xd afdesign afphoto indd eps`
  - fonts D: `ttf otf woff woff2` · books D: `epub mobi azw3 djvu` · officialDocs D: `udf`
  - certificates D: `der pem cer crt p12 pfx mobileprovision kdbx env`
  - `key`: `utTypeIdentifier == "com.apple.iwork.keynote.key"` → presentations D, aksi → certificates D (kodda özel durum).
- Sıra: (1) klasör → histogram (bilinen uzantılı dosyalar `extensionMap` ile kategoriye eşlenir; tek kategori ≥ %70 → o kategori W, aksi `other` W; klasör **asla** decisive değil). (2) Ad kalıpları (ad `ascii` + küçük harf üzerinde):
  - `^(screenshot|ekran resmi|ekran goruntusu)\b` + görsel uzantı → screenshots D, hint = `(\d{1,2})[.:](\d{2})[.:](\d{2})` → `HH-MM-SS` (saat iki haneli)
  - `^(screen recording|ekran kaydi)\b` + video uzantı → screenRecordings D, aynı hint
  - `^(img|pxl|dsc|dcim)_?\d+` veya `^whatsapp (image|video|gorsel)` → görsel uzantı photos D, video uzantı videos D, hint `nil`
  - `(fatura|invoice|e-arsiv|e-fatura|receipt|dekont)` → invoices D; `(sozlesme|contract|agreement)` → contracts D — yalnızca uzantı documents/images/spreadsheets'e eşleniyorsa veya eşlenmiyorsa.
  (3) `extensionMap`. (4) `other` W.

- [ ] **Step 1: Write the failing tests**

```swift
struct RuleEngineTests {
    let e = RuleEngine(settings: Settings())
    func m(_ n: String, utType: String? = nil) -> RuleMatch { e.match(.stub(n, utType: utType)) }
    @Test func screenshotsAndRecordings() {
        #expect(m("Screenshot 2025-03-14 at 10.22.31.png") == RuleMatch(categoryID: "screenshots", strength: .decisive, descriptionHint: "10-22-31"))
        #expect(m("Ekran Resmi 2025-03-14 10.22.31.png").descriptionHint == "10-22-31")
        #expect(m("Ekran Görüntüsü 2025-03-14 9.05.07.png").descriptionHint == "09-05-07")
        #expect(m("Ekran Kaydı 2025-03-14 10.22.31.mov").categoryID == "screenRecordings")
    }
    @Test func cameraNames() {
        #expect(m("IMG_4821.HEIC") == RuleMatch(categoryID: "photos", strength: .decisive, descriptionHint: nil))
        #expect(m("IMG_4822.MOV").categoryID == "videos")
        #expect(m("PXL_20240101_123.jpg").categoryID == "photos")
        #expect(m("WhatsApp Image 2024-05-01 at 12.00.00.jpeg").categoryID == "photos")
    }
    @Test func keywordRules() {
        #expect(m("e-Arşiv Fatura 123.pdf") == RuleMatch(categoryID: "invoices", strength: .decisive, descriptionHint: nil))
        #expect(m("Kira Sözleşmesi.docx").categoryID == "contracts")
        #expect(m("fatura-ozet.mp4").categoryID == "videos")
    }
    @Test(arguments: [("song.mp3", "audio"), ("setup.dmg", "installers"), ("font.otf", "fonts"), ("design.pxd", "design"), ("map.geojson", "data"), ("main.swift", "code"), ("book.epub", "books"), ("talep.udf", "officialDocs"), ("cert.der", "certificates"), ("yedek.tar.gz", "archives")])
    func extensionDecisive(name: String, category: String) {
        #expect(m(name) == RuleMatch(categoryID: category, strength: .decisive, descriptionHint: nil))
    }
    @Test(arguments: [("document.pdf", "documents"), ("export.json", "data"), ("list.csv", "spreadsheets"), ("files.zip", "archives"), ("tool.jar", "installers"), ("notes.md", "documents"), ("thing.xyz", "other")])
    func extensionWeak(name: String, category: String) {
        #expect(m(name) == RuleMatch(categoryID: category, strength: .weak, descriptionHint: nil))
    }
    @Test func keynoteVersusKey() {
        #expect(m("sunum.key", utType: "com.apple.iwork.keynote.key").categoryID == "presentations")
        #expect(m("server.key").categoryID == "certificates")
    }
    @Test func folders() {
        #expect(e.match(.stub("A", kind: .folder, histogram: ["jpg": 8, "txt": 1])) == RuleMatch(categoryID: "images", strength: .weak, descriptionHint: nil))
        #expect(e.match(.stub("B", kind: .folder, histogram: ["jpg": 3, "pdf": 3])).categoryID == "other")
        #expect(e.match(.stub("C", kind: .folder)).strength == .weak)
    }
    @Test func everyMappedExtensionIsKnown() {
        #expect(Set(DefaultRules.extensionMap.keys).isSubset(of: KnownExtensions.all))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter RuleEngineTests`.
- [ ] **Step 3: Implement** `DefaultRules`, `RuleEngine`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): rule engine with decisive and weak matches"`

---

### Task 7: ContentPreview

**Files:**
- Create: `Sources/TrimlyCore/Scan/ContentPreview.swift`
- Test: `Tests/TrimlyCoreTests/Scan/ContentPreviewTests.swift` (PDF üretimi için test içinde `CGContext(url:mediaBox:)` + `CTLineDraw` yardımcı fonksiyonu; docx için `NSAttributedString.data(from:documentAttributes: [.documentType: .officeOpenXML])`)

**Interfaces:**
- Produces: `enum ContentPreview { static func text(for url: URL, maxCharacters: Int, pdfPages: Int) -> String? }`
- Kurallar: düz metin uzantıları `txt md markdown json geojson csv tsv xml yaml yml log html htm` → ilk `maxCharacters * 4` bayt, `String(decoding:as: UTF8.self)`, `prefix(maxCharacters)`; `pdf` → `PDFDocument` ilk `pdfPages` sayfanın `string`'i; `doc docx rtf odt` → `NSAttributedString(url:options:documentAttributes:)`.`string`, `documentType` açıkça verilir: `rtf → .rtf`, `docx → .officeOpenXML`, `doc → .docFormat`, `odt → .openDocument`; diğerleri `nil`. Boşluk/boş sonuç → `nil`. Çağıran (Planner) kritik öğeler için bu fonksiyonu **hiç çağırmaz**.

- [ ] **Step 1: Write the failing tests**

```swift
struct ContentPreviewTests {
    @Test func truncatesText() throws {
        let u = try TestFS.file("notes.txt", in: try TestFS.tempDir(), contents: String(repeating: "a", count: 3000))
        #expect(ContentPreview.text(for: u, maxCharacters: 1500, pdfPages: 1)?.count == 1500)
    }
    @Test func pdfRespectsPageLimit() throws {
        let u = try makePDF(["Sayfa bir fatura", "Sayfa iki toplam"], in: try TestFS.tempDir())
        let one = try #require(ContentPreview.text(for: u, maxCharacters: 1500, pdfPages: 1))
        #expect(one.contains("Sayfa bir"))
        #expect(one.contains("Sayfa iki") == false)
        #expect(ContentPreview.text(for: u, maxCharacters: 4000, pdfPages: 2)?.contains("Sayfa iki") == true)
    }
    @Test func readsDocx() throws {
        let u = try makeDocx("Kira sözleşmesi metni", in: try TestFS.tempDir())
        #expect(ContentPreview.text(for: u, maxCharacters: 1500, pdfPages: 1)?.contains("Kira sözleşmesi") == true)
    }
    @Test func readsRTFWithTurkishCharacters() throws {
        // NSAttributedString("Şirket sözleşmesi ğüı").data(... documentType: .rtf) → "s.rtf"
        // → önizleme "Şirket sözleşmesi ğüı" içerir
    }
    @Test func binaryAndEmptyReturnNil() throws {
        let dir = try TestFS.tempDir()
        #expect(ContentPreview.text(for: try TestFS.file("x.png", in: dir), maxCharacters: 1500, pdfPages: 1) == nil)
        #expect(ContentPreview.text(for: try TestFS.file("e.txt", in: dir, contents: "  \n"), maxCharacters: 1500, pdfPages: 1) == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ContentPreviewTests`.
- [ ] **Step 3: Implement** `ContentPreview` + test yardımcıları `makePDF`, `makeDocx`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): local content preview for text, pdf, docx"`

---

### Task 8: LLM katmanı — protokol, şema, prompt, OllamaProvider

**Files:**
- Create: `Sources/TrimlyCore/LLM/LLMProvider.swift`, `ResponseSchema.swift`, `PromptBuilder.swift`, `OllamaProvider.swift`
- Create: `Sources/TrimlyCore/LLM/HTTPTransport.swift`, `Tests/TrimlyCoreTests/Fixtures/RecordingTransport.swift`, `Fixtures/MockLLMProvider.swift`
- Test: `Tests/TrimlyCoreTests/LLM/OllamaProviderTests.swift`, `PromptBuilderTests.swift`

**Interfaces:**
- Consumes: `EntryKind` (Task 1)
- Produces:
  - `struct ClassificationRequest: Sendable, Equatable { var name: String; var fileExtension: String; var kind: EntryKind; var sizeBytes: Int64?; var createdAt: Date?; var modifiedAt: Date?; var utType: String?; var sourceHost: String?; var spotlightTitle: String?; var spotlightAuthors: [String]; var ruleHintCategoryFolder: String?; var folderSampleNames: [String]; var contentPreview: String?; var allowedFolders: [String]; static func sourceHost(from whereFroms: [String]) -> String? }` — `sourceHost`: ilk geçerli URL'nin `host + path`, query/fragment yok.
  - `struct ClassificationResult: Codable, Equatable, Sendable { let targetFolder: String; let suggestedName: String; let confidence: Double; let reason: String }` (CodingKeys `target_folder`, `suggested_name`, `confidence`, `reason`).
  - `struct ProviderHealth: Sendable, Equatable { let reachable: Bool; let availableModels: [String] }`
  - `enum LLMError: Error, Equatable { case folderNotAllowed(String), confidenceOutOfRange(Double), malformedResponse, http(Int), unreachable }`
  - `protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`; `struct URLSessionTransport: HTTPTransport { init(session: URLSession = .shared) }` — `session.data(for:)`, `HTTPURLResponse` değilse `LLMError.malformedResponse`; `URLError` (iptal hariç) → `LLMError.unreachable`.
  - `protocol LLMProvider: Sendable { func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult; func unload(model: String) async; func health() async -> ProviderHealth }`
  - `enum ResponseSchema { static func json(allowedFolders: [String]) -> [String: Any] }` — spec §5.5 şeması birebir (`enum` = `allowedFolders`, `additionalProperties: false`, `required` 4 alan, `confidence` 0…1, `reason.maxLength` 160).
  - `enum PromptBuilder { static let systemPrompt: String; static func userMessage(_ r: ClassificationRequest) -> String }` — sistem promptu Türkçe; şunları söyler: yalnızca listedeki klasörlerden biri; `suggested_name` 2–6 kelime, tarih/uzantı/kategori yok; `confidence` dürüst (emin değilsen < 0.5); `reason` Türkçe ≤ 160 karakter. Kullanıcı mesajı alanları etiketli satırlar; önizleme varsa `İçerik önizlemesi:` başlığıyla, yoksa bu başlık hiç yok.
  - `struct OllamaProvider: LLMProvider { init(baseURL: URL, timeout: TimeInterval, keepAlive: String, transport: any HTTPTransport = URLSessionTransport()) }` (istek `timeoutInterval = timeout`)` — `classify`: Global Constraints'teki gövde; yanıt `message.content` JSON → `ClassificationResult`; `targetFolder ∉ allowedFolders` → `.folderNotAllowed(targetFolder)`, `confidence ∉ 0...1` → `.confidenceOutOfRange(confidence)`, decode hatası → `.malformedResponse`, HTTP ≠ 200 → `.http(code)`; bu hatalardan herhangi biri → 1 kez yeniden dener, sonra fırlatır; `CancellationError`/`URLError(.cancelled)` yeniden denenmez, aynen fırlatılır. `unload`: `POST /api/generate {"model": m, "keep_alive": 0}`, hatalar yutulur. `health`: `GET /api/tags` → `models[].name`; hata → `reachable: false`.
  - Test destek: `actor RecordingTransport: HTTPTransport { init(responses: [Result<(Int, Data), any Error>]); var requests: [URLRequest]; func bodyJSON(at index: Int) throws -> [String: Any] }` — yanıtları sırayla döner (liste biterse son yanıt tekrar); `actor MockLLMProvider: LLMProvider { init(results: [String: Result<ClassificationResult, Error>] = [:], defaultResult: Result<ClassificationResult, Error>? = nil, cancelAfterCalls: Int? = nil); var requests: [(ClassificationRequest, String)]; var unloaded: [String]; var events: [String] /* "unload:<m>", "classify:<m>:<name>" */ }` — ada göre sonuç, `cancelAfterCalls` aşılınca `CancellationError` fırlatır.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite(.tags(.networking)) struct OllamaProviderTests {
    let allowed = ["Belgeler", "Faturalar", "Diger"]
    func provider(_ t: RecordingTransport) -> OllamaProvider {
        OllamaProvider(baseURL: URL(string: "http://localhost:11434")!, timeout: 60, keepAlive: "2m", transport: t)
    }
    func reply(_ content: String) -> Data { try! JSONSerialization.data(withJSONObject: ["message": ["content": content]]) }
    var request: ClassificationRequest { ClassificationRequest(name: "download (3).pdf", fileExtension: "pdf", kind: .file, sizeBytes: 1, createdAt: nil, modifiedAt: nil, utType: nil, sourceHost: nil, spotlightTitle: nil, spotlightAuthors: [], ruleHintCategoryFolder: "Belgeler", folderSampleNames: [], contentPreview: nil, allowedFolders: allowed) }

    @Test func chatRequestBodyMatchesContract() async throws {
        let t = RecordingTransport(responses: [.success((200, reply(#"{"target_folder":"Faturalar","suggested_name":"Enerjisa Ocak","confidence":0.91,"reason":"Fatura no"}"#)))])
        _ = try await provider(t).classify(request, model: "qwen3:4b")
        let req = try #require(await t.requests.first)
        #expect(req.url?.path == "/api/chat" && req.httpMethod == "POST")
        let body = try await t.bodyJSON(at: 0)
        #expect(body["model"] as? String == "qwen3:4b" && body["stream"] as? Bool == false && body["think"] as? Bool == false)
        #expect(body["keep_alive"] as? String == "2m")
        let opts = body["options"] as! [String: Any]
        #expect(opts["temperature"] as? Double == 0 && opts["num_ctx"] as? Int == 4096)
        let format = body["format"] as! [String: Any]
        #expect(format["required"] as? [String] == ["target_folder", "suggested_name", "confidence", "reason"])
        #expect(format["additionalProperties"] as? Bool == false)
        #expect(((format["properties"] as! [String: Any])["target_folder"] as! [String: Any])["enum"] as? [String] == allowed)
        #expect((body["messages"] as! [[String: Any]]).map { $0["role"] as! String } == ["system", "user"])
    }
    @Test func decodesResult() async throws { /* yukarıdaki yanıt → result == ClassificationResult("Faturalar","Enerjisa Ocak",0.91,"Fatura no") */ }
    @Test func rejectsFolderOutsideEnum() async { /* target_folder "Uydurma" → await #expect(throws: LLMError.folderNotAllowed("Uydurma")) { ... } */ }
    @Test func rejectsConfidenceOutOfRange() async { /* 1.4 → throws LLMError.confidenceOutOfRange(1.4) */ }
    @Test func retriesOnceThenThrows() async { /* iki yanıt da 500 → throws LLMError.http(500), await t.requests.count == 2 */ }
    @Test func succeedsOnRetry() async throws { /* 1. çağrı 500, 2. geçerli → sonuç döner, count == 2 */ }
    @Test func unloadSendsKeepAliveZero() async throws { /* path "/api/generate", body keep_alive == 0, model */ }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TRIMLY_OLLAMA_TESTS"] == "1"), .timeLimit(.minutes(1)))
    func liveOllamaReturnsSchemaValidResult() async throws {
        /* gerçek OllamaProvider(baseURL: localhost:11434, transport: URLSessionTransport()), qwen3:4b,
           "Enerjisa_fatura_ocak.pdf" isteği → result.targetFolder ∈ allowed, 0...1 aralığında confidence */
    }
    @Test func healthListsModels() async { /* {"models":[{"name":"qwen3:4b"}]} → reachable, ["qwen3:4b"]; transport .failure(LLMError.unreachable) → reachable == false */ }
}

struct PromptBuilderTests {
    @Test func previewSectionOnlyWhenPresent() { /* contentPreview nil → !contains("İçerik önizlemesi"); "Fatura No 123" → contains both */ }
    @Test func sourceHostDropsQuery() {
        #expect(ClassificationRequest.sourceHost(from: ["https://www.enerjisa.com.tr/fatura/indir?token=abc"]) == "www.enerjisa.com.tr/fatura/indir")
        #expect(ClassificationRequest.sourceHost(from: []) == nil)
    }
    @Test func listsAllowedFolders() { /* userMessage contains every allowed folder name */ }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "OllamaProviderTests|PromptBuilderTests"`.
- [ ] **Step 3: Implement** LLM dosyaları (`HTTPTransport`/`URLSessionTransport` dahil) + `RecordingTransport` + `MockLLMProvider`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): LLM provider abstraction with Ollama JSON-schema client"`

---

### Task 9: TargetResolver + TargetAssigner

**Files:**
- Create: `Sources/TrimlyCore/Naming/TargetResolver.swift`
- Test: `Tests/TrimlyCoreTests/Naming/TargetResolverTests.swift`

**Interfaces:**
- Consumes: `Settings`, `Plan`, `PlanItem`, `NamingTemplate`, `DateResolver.dayString`, `Normalizer.fullExtension` (Task 1–3)
- Produces:
  - `struct TargetResolver { init(root: URL, settings: Settings); func folderURL(categoryFolder: String, date: Date) -> URL; mutating func reserve(fileName: String, in folder: URL, source: URL) -> URL }` — `inPlace` → `root/<folder>`, `central` → `archiveRoot` (`~` genişletilir)`/<folder>`; `yearSubfolders` → `/<YYYY>`. `reserve`: aday yol kaynakla aynıysa (standardize, büyük/küçük harf duyarsız) kaynağı döner; değilse diskteki klasör içeriği (küçük harf ad kümesi, klasör başına bir kez okunur) **ve** bu resolver'da önceden ayrılmış adlar ile büyük/küçük harf duyarsız çakışmada `gövde_2.uzantı`, `_3`… (bileşik uzantı korunur). Hedef klasör diskte henüz yoksa disk kümesi boştur, çakışmayı yalnızca ayrılmış adlar belirler. **Diskteki bir ad, sahibi aynı planda başka yere taşınacak olsa bile dolu sayılır** (zincirleme/takas taşıma yok; muhafazakâr). `inPlace` modda bu durum oluşmaz, çünkü hedef kategori klasörleri tarama dışıdır; yalnızca `central` modda arşivin içindeki bir klasör düzenlenirken görülür.
  - `enum TargetAssigner { static func assign(_ plan: inout Plan) }` — `plan.settingsSnapshot` ve `plan.root` ile yeni bir `TargetResolver`; `status != .skipped` ve `categoryID != nil` öğeleri **ada göre artan** sırada işler: klasör → `NamingTemplate.folderName`, diğerleri → `NamingTemplate.fileName(preset:, day: dayString(resolvedDate), categoryTag: tag(lang), description: description ?? "Dosya"/"File", originalName: name, fileExtension: fileExtension)`; hedef = `reserve(...)`. Hedef kaynağa eşitse `status = .skipped`, `skipReason = "Zaten düzenli"`, `approved = false`. Diğer öğelerin `target`'ı `nil`.

- [ ] **Step 1: Write the failing tests**

```swift
struct TargetResolverTests {
    @Test func inPlaceAndYearFolders() {
        let root = URL(filePath: "/tmp/r")
        #expect(TargetResolver(root: root, settings: Settings()).folderURL(categoryFolder: "Faturalar", date: .now).path == "/tmp/r/Faturalar")
        var s = Settings(); s.yearSubfolders = true
        let d = ISO8601DateFormatter().date(from: "2025-06-01T12:00:00Z")!
        #expect(TargetResolver(root: root, settings: s).folderURL(categoryFolder: "Faturalar", date: d).path == "/tmp/r/Faturalar/2025")
    }
    @Test func centralExpandsTilde() {
        var s = Settings(); s.targetMode = .central
        #expect(TargetResolver(root: URL(filePath: "/tmp/r"), settings: s).folderURL(categoryFolder: "Faturalar", date: .now).path
                == FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents/Arsiv/Faturalar").path)
    }
    @Test func suffixesOnDiskConflictCaseInsensitive() throws {
        let root = try TestFS.tempDir(); let f = try TestFS.folder("Faturalar", in: root); try TestFS.file("A.pdf", in: f)
        var r = TargetResolver(root: root, settings: Settings())
        #expect(r.reserve(fileName: "a.pdf", in: f, source: root.appending(path: "x.pdf")).lastPathComponent == "a_2.pdf")
    }
    @Test func suffixesWithinPlan() throws {
        let root = try TestFS.tempDir(); let f = root.appending(path: "Faturalar")
        var r = TargetResolver(root: root, settings: Settings())
        let src = root.appending(path: "s")
        #expect([r.reserve(fileName: "x.pdf", in: f, source: src), r.reserve(fileName: "x.pdf", in: f, source: src), r.reserve(fileName: "X.PDF", in: f, source: src)].map(\.lastPathComponent) == ["x.pdf", "x_2.pdf", "X_3.PDF"])
    }
    @Test(.tags(.edgeCase)) func compoundExtensionSuffix() throws { /* "y.tar.gz" iki kez → ["y.tar.gz", "y_2.tar.gz"] */ }
    @Test func diskNameStaysOccupiedEvenIfOwnerIsAlsoInPlan() throws {
        // central: root = <arşiv>/Faturalar, diskte "a.pdf" ve "b.pdf"; b.pdf "a.pdf" adını isterse → "a_2.pdf"
    }
    @Test func sameAsSourceReturnsSource() throws { /* f/x.pdf diskte var; reserve("x.pdf", in: f, source: f/x.pdf) == source */ }
    @Test func assignerIsDeterministicAndSkipsSkipped() throws {
        /* plan: "b.pdf" ve "a.pdf" ikisi invoices, description "Enerjisa-Ocak", aynı resolvedDate; "c.pdf" skipped; "d.pdf" categoryID nil
           → a.pdf hedefi ".../Faturalar/<day>_Fatura_Enerjisa-Ocak.pdf", b.pdf "..._2.pdf"; c ve d target nil */
    }
    @Test func assignerUsesFolderNameForFolders() throws { /* kind .folder "Tatil Fotoğrafları" photos → ".../Fotograflar/Tatil-Fotograflari" */ }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter TargetResolverTests`.
- [ ] **Step 3: Implement** `TargetResolver`, `TargetAssigner`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): target resolver with case-insensitive conflict suffixes"`

---

### Task 10: PlanStore + Planner (1. aşama, checkpoint, devam, istatistik)

**Files:**
- Create: `Sources/TrimlyCore/Planning/PlanStore.swift`, `Planner.swift`
- Test: `Tests/TrimlyCoreTests/Planning/PlannerTests.swift`

**Interfaces:**
- Consumes: Task 1–9'un tamamı (`Scanner`, `MetadataReader`, `IgnoreRules`, `CriticalDetector`, `RuleEngine`, `ContentPreview`, `LLMProvider`, `PromptBuilder`/`ClassificationRequest`, `DescriptionSanitizer`, `DateResolver`, `TargetAssigner`)
- Produces:
  - `struct PlanStore: Sendable { init(directory: DataDirectory); func save(_: Plan) throws /* atomik yazım */; func load(id: String) throws -> Plan /* yoksa PlanError.notFound */; func list() throws -> [Plan] /* en yeni önce */; func latestResumable(root: URL, now: Date) throws -> Plan? /* state == .inProgress, aynı standardize kök, createdAt > now - 24 saat */ }`
  - `struct PlanProgress: Sendable { let processed: Int; let total: Int; let stage: Int }`
  - `struct PatternCount: Codable, Equatable, Sendable { let pattern: String; let count: Int }`
  - `struct PlanStats: Codable, Equatable, Sendable { let total, skipped, decisiveRule, sentToLLM, ready, review, critical: Int; let reviewByReason: [String: Int]; let topReviewPatterns: [PatternCount] }`
  - `struct Planner: Sendable { init(settings: Settings, store: PlanStore, provider: (any LLMProvider)?, now: @escaping @Sendable () -> Date = { Date() }, progress: (@Sendable (PlanProgress) -> Void)? = nil); @concurrent func makePlan(root: URL, useLLM: Bool) async throws -> Plan; static func stats(_: Plan) -> PlanStats }`
- Kararlar:
  - Plan id: `yyyy-MM-dd'T'HH-mm-ss_<Normalizer.slug(root.lastPathComponent)>`; çakışırsa `-2`. Öğe id: `SHA256(source.standardizedFileURL.path)` ilk 8 hex.
  - Akış: devam edilebilir plan varsa onu al (aynı id; `classified == true` öğeler korunur), yoksa yeni plan (`state = .inProgress`, `settingsSnapshot = settings`). Tara → her öğe: `skipReason` → `skipped` (`classified = true`). Değilse `critical`, `RuleMatch`:
    - decisive + klasör değil → `categoryID`, `confidence 1.0`, `decidedBy .rule`, `status` = kritikse `.critical` aksi `.ready`.
    - aksi halde LLM kullanılabiliyorsa (`useLLM && provider != nil && settings.llmEnabled`) kuyruğa; değilse yedek: kategori = kuralınki, `confidence 0.6`, `decidedBy .rule`, `status` = kritik → `.critical`; klasör → `.review/.folder`; aksi `.review/.weakRuleNoLLM`.
  - LLM kuyruğu `batchSize`'lık partilerde, sırayla, eşzamanlılık 1. Her öğeden önce `try Task.checkCancellation()`. İstek: `contentPreview` yalnızca `!critical && settings.contentPreview && kind == .file` ise `ContentPreview.text(for:maxCharacters: 1500, pdfPages: 1)`; `allowedFolders` = ayardaki dilde tüm kategori klasörleri; model `stage1Model`. Başarı → kategori `category(forFolderName:)`, `reason` 160'a kesilir, `decidedBy .llm1`, `status`: kritik → `.critical`; klasör → `.review/.folder`; `confidence < threshold` → `.review/.lowConfidence`; aksi `.ready`. Hata (`CancellationError` hariç — o yeniden fırlatılır) → kural kategorisi, `confidence 0.6`, `status` kritik → `.critical` aksi `.review/.llmError`, `reason = "LLM yanıtı geçersiz: <hata>"`. Her parti bitince plan `store.save` ile kaydedilir; `progress` çağrılır.
  - Açıklama zinciri: `sanitize(llm.suggestedName) ?? sanitize(rule.descriptionHint) ?? sanitize(gövde) ?? slug(gövde) (boş değilse) ?? "Dosya"/"File"` — `categoryTerms` = seçili kategorinin terimleri.
  - Bitiş: `TargetAssigner.assign`, `approved = (status == .ready && !critical && kind != .folder)`, `state = .ready`, kaydet.
  - `stats`: `decisiveRule` = `decidedBy == .rule && status != .review`; `sentToLLM` = `decidedBy ∈ {llm1, llm2}` veya `reviewReason == .llmError`; `topReviewPatterns` = `review` öğelerinde desen (`klasör` veya `.<uzantı>`, uzantısız `(uzantısız)`), azalan, en çok 10.

- [ ] **Step 1: Write the failing tests**

```swift
struct PlannerTests {
    // fixture(): temp root + DataDirectory; dosyalar (modified/created .twoDaysAgo):
    //  "Screenshot 2025-03-14 at 10.22.31.png", "download (3).pdf" (contents "Fatura No 123", created 2025-02-10T12:00:00 yerel),
    //  "cert.der", "kimlik.pdf", "song.mp3", ".DS_Store", "myproj/.git/", "Album/" (8 jpg)
    @Test func rulesOnlyPlanWithoutLLM() async throws {
        let f = try PlannerFixture(); let mock = MockLLMProvider()
        let plan = try await f.planner(mock).makePlan(root: f.root, useLLM: false)
        let shot = plan.item("Screenshot 2025-03-14 at 10.22.31.png")
        #expect(shot.status == .ready && shot.decidedBy == .rule && shot.approved)
        #expect(shot.target?.path == f.root.appending(path: "Ekran-Goruntuleri/2025-03-14_Ekran-Goruntusu_10-22-31.png").path)
        let pdf = plan.item("download (3).pdf")
        #expect(pdf.status == .review && pdf.reviewReason == .weakRuleNoLLM && pdf.confidence == 0.6 && pdf.categoryID == "documents" && pdf.approved == false)
        #expect(plan.item("cert.der").status == .critical && plan.item("cert.der").approved == false)
        #expect(plan.item(".DS_Store").skipReason == "Sistem dosyası")
        #expect(plan.item("myproj").skipReason == "Proje klasörü (.git)")
        #expect(plan.item("Album").reviewReason == .folder && plan.item("Album").approved == false)
        #expect(await mock.requests.isEmpty)
        #expect(plan.state == .ready)
    }
    @Test func llmClassifiesWeakItems() async throws {
        // mock: "download (3).pdf" → ("Faturalar", "Enerjisa Ocak 2025-01-31.pdf", 0.91, "Fatura no")
        // → status .ready, decidedBy .llm1, approved, target lastPathComponent == "2025-02-10_Fatura_Enerjisa-Ocak.pdf", parent "Faturalar"
    }
    @Test func lowConfidenceGoesToReview() async throws { /* mock 0.5 → .review/.lowConfidence, approved == false */ }
    @Test func criticalContentNeverSent() async throws {
        // mock defaultResult confidence 0.99 → "kimlik.pdf": request.contentPreview == nil, status .critical, approved == false
        // "cert.der" (decisive) için hiç istek yok
    }
    @Test func providerFailureFallsBack() async throws {
        // mock defaultResult .failure(LLMError.unreachable) → pdf .review/.llmError, categoryID "documents"; screenshot hâlâ .ready
    }
    @Test func checkpointsEveryBatchAndResumes() async throws {
        // settings.batchSize = 2; kök: 5 adet "belge<i>.pdf"; mock1 cancelAfterCalls: 3
        // makePlan → throws CancellationError; store.latestResumable(...) != nil, LLM ile sınıflanmış (decidedBy .llm1) öğe sayısı == 2
        // mock2 (hepsi geçerli) ile makePlan → aynı plan id, mock2.requests.count == 3, state .ready
    }
    @Test func resumeOnlyWithin24Hours() async throws { /* createdAt now-25h olan inProgress plan → yeni id */ }
    @Test func statsCountsByReason() async throws {
        // rulesOnly planı → stats.reviewByReason["weakRuleNoLLM"] == 2 (download (3).pdf + ... ), ["folder"] == 1,
        // critical == 2, skipped == 2, topReviewPatterns.first?.pattern == ".pdf"
    }
    @Test(.tags(.edgeCase)) func emojiOnlyNameFallsBack() async throws { /* "🔥🔥.png" → target lastPathComponent hasSuffix "_Gorsel_Dosya.png" */ }
}
```

`PlannerFixture` (`Tests/TrimlyCoreTests/Fixtures/PlannerFixture.swift`, Task 11–13 testleri de kullanır): `root`, `data: DataDirectory`, `store: PlanStore`, `settings: Settings`, `func planner(_ p: (any LLMProvider)?, now: Date = Date()) -> Planner`; `Plan.item(_ name:) -> PlanItem` test uzantısı.

- [ ] **Step 2: Run to verify failure** — `swift test --filter PlannerTests`.
- [ ] **Step 3: Implement** `PlanStore`, `Planner.makePlan`, `Planner.stats`.
- [ ] **Step 4: Run tests** → geçer (`statsCountsByReason`'daki sayıları fixture'a göre düzelt; değerler fixture ile tutarlı olmalı, kod uydurulmaz).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): planner with rule/LLM pipeline, checkpoints and stats"`

---

### Task 11: 2. aşama review + PlanEditor (elle karar, toplu onay, kritik bariyeri)

**Files:**
- Modify: `Sources/TrimlyCore/Planning/Planner.swift` (`review(planID:)` ekle)
- Create: `Sources/TrimlyCore/Planning/PlanEditor.swift`
- Test: `Tests/TrimlyCoreTests/Planning/ReviewAndEditorTests.swift`

**Interfaces:**
- Consumes: Task 10 `Planner`, `PlanStore`, `TargetAssigner`
- Produces:
  - `extension Planner { @concurrent func review(planID: String) async throws -> Plan }` — `state == .applied` → `PlanError.alreadyApplied`; `inProgress` → `PlanError.notReady`. Adaylar: `status == .review` veya `.critical`. Önce `provider.unload(model: stage1Model)`. Kökü yeniden tarar, öğeyi id ile eşler (bulunamayan atlanır). İstek: önizleme yalnızca kritik değilse ve dosyaysa `maxCharacters: 4000, pdfPages: 2`; model `stage2Model`. Sonuç: `categoryID`, `description`, `confidence`, `reason`, `decidedBy .llm2`; kritik → `status` `.critical` kalır, **`approved`'a dokunulmaz**; klasör → `.review/.folder`; `confidence ≥ threshold` → `.ready` + `approved = true`; aksi `.review/.lowConfidence`. Hata → öğe değişmez. Sonra `TargetAssigner.assign`, kaydet.
  - `enum PlanEditor { static func set(_ plan: inout Plan, itemID: String, categoryID: String?, description: String?, approve: Bool?) throws; static func bulkApprove(_ plan: inout Plan, categoryID: String?, reviewReason: ReviewReason?, minConfidence: Double?, includeFolders: Bool) -> Int }`
    - `set`: bilinmeyen öğe → `.itemNotFound`, bilinmeyen kategori → `.unknownCategory`, `applied` plan → `.alreadyApplied`. Kategori/açıklama verilirse `decidedBy = .manual`, açıklama `DescriptionSanitizer` + yedek zinciriyle; `status` kritikse `.critical` kalır, değilse `.ready`, `reviewReason = nil`; `approve` yalnızca açıkça verilirse uygulanır (kritik dahil — bu tek açık yol). Sonra `TargetAssigner.assign`.
    - `bulkApprove`: `approved = true` yapılan öğe sayısını döner. **Kritik öğeler, `skipped` ve `target == nil` öğeler asla kapsanmaz**; klasörler yalnızca `includeFolders`; filtreler AND.

- [ ] **Step 1: Write the failing tests**

```swift
struct ReviewAndEditorTests {
    @Test func reviewUnloadsStage1ThenUsesStage2() async throws {
        // rulesOnly plan; mock2 → events.first == "unload:qwen3:4b"; tüm classify olayları "classify:ministral-3:14b:..."
    }
    @Test func reviewPromotesConfidentItems() async throws { /* review pdf + mock 0.9 → .ready, .llm2, approved */ }
    @Test func reviewNeverApprovesCritical() async throws { /* "kimlik.pdf" mock 0.99 → .critical, approved == false, decidedBy .llm2, categoryID set, request.contentPreview == nil */ }
    @Test func reviewSendsLongerPreview() async throws {
        // "uzun.txt" (5000 karakter, weak) → istek önizlemesi count == 4000
    }
    @Test func reviewRejectsAppliedPlan() async throws { /* state .applied → #expect(throws: PlanError.alreadyApplied) */ }
    @Test func setManualCategoryRecomputesTarget() throws {
        // set(item "download (3).pdf", categoryID "invoices", description "Kira Ocak", approve true)
        // → decidedBy .manual, .ready, approved, target parent "Faturalar", lastPathComponent contains "_Fatura_Kira-Ocak"
    }
    @Test func setOnCriticalKeepsStatusButAllowsExplicitApprove() throws { /* status .critical, approved true */ }
    @Test func setRejectsUnknownCategory() throws { /* #expect(throws: PlanError.unknownCategory("yok")) */ }
    @Test func bulkApproveSkipsCriticalAndFolders() throws {
        // review: 2 dosya (non-critical), 1 critical, 1 folder
        // bulkApprove(nil, nil, nil, includeFolders: false) == 2; critical/folder approved == false
        // bulkApprove(nil, nil, nil, includeFolders: true) == 1 (folder); critical hâlâ approved == false
    }
    @Test func bulkApproveFilters() throws { /* minConfidence 0.8 yalnız ≥0.8 olanlar; reviewReason .lowConfidence yalnız onlar; categoryID "documents" yalnız onlar */ }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ReviewAndEditorTests`.
- [ ] **Step 3: Implement** `Planner.review`, `PlanEditor`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): stage-2 review, manual edits and bulk approve with critical barrier"`

---

### Task 12: Journal + Executor + Recovery

**Files:**
- Create: `Sources/TrimlyCore/Execution/Journal.swift`, `Executor.swift`, `Recovery.swift`
- Test: `Tests/TrimlyCoreTests/Execution/JournalTests.swift`, `ExecutorTests.swift`

**Interfaces:**
- Consumes: `Plan`, `PlanStore`, `DataDirectory`, `TargetResolver` (sonek mantığı), Task 10 `Planner` (testlerde plan üretmek için)
- Produces:
  - `enum JournalOp: String, Codable, Sendable { case mkdir, move, undo }`; `enum JournalState: String, Codable, Sendable { case pending, done, failed, skipped }`
  - `struct JournalEntry: Codable, Equatable, Sendable { var seq: Int; var type: String?; var op: JournalOp?; var ref: Int?; var state: JournalState?; var from: String?; var to: String?; var path: String?; var size: Int64?; var mtime: Date?; var runID: String?; var planID: String?; var root: String?; var at: Date?; var message: String? }` — spec §5.9 satır biçimi; nil alanlar yazılmaz.
  - `struct Journal: Sendable { let url: URL; private(set) var entries: [JournalEntry]; static func create(at: URL, header: JournalEntry) throws -> Journal; static func open(at: URL) throws -> Journal; @discardableResult mutating func append(_ e: JournalEntry) throws -> Int /* seq atar; FileHandle(forWritingTo:) → seekToEnd → satır + "\n" → synchronize() → close */; func effectiveState(of seq: Int) -> JournalState? /* kendi state'i veya ref'i ona olan son satırın state'i */ }` — `@unchecked Sendable` yok; değer tipi, her append dosyayı açıp kapatır.
  - `struct SkippedEntry: Codable, Equatable, Sendable { let path: String; let reason: String }`; `struct RunSummary: Sendable { let runID: String; let moved: Int; let skipped: [SkippedEntry]; let failed: [SkippedEntry] }`
  - `enum ExecutionError: Error, Equatable { case alreadyApplied, notReady }`
  - `struct Executor { init(directory: DataDirectory, now: @escaping @Sendable () -> Date = { Date() }); func apply(planID: String) throws -> RunSummary }`
  - `enum Recovery { @discardableResult static func recover(journalAt: URL) throws -> Int; @discardableResult static func recoverAll(in: DataDirectory) throws -> Int }`
- Kararlar:
  - Run id `r-yyyyMMdd-HHmmss` (varsa `-2`), dosya `runs/<runID>.jsonl`, header `{type:"header", runID, planID, root, at}`.
  - Öğe sırası: plan sırası; yalnızca `approved && target != nil && status != .skipped`.
  - Doğrulama (birebir sebepler): `SourceFingerprint.read` nil → `"Kaynak bulunamadı"`; `plan.sourceFingerprint.matches(current) == false` → `"Kaynak değişmiş"`. Hedef klasör zinciri: yoksa üstten alta oluştur, her oluşturulan için `mkdir` satırı (`state: done`). Hedef artık doluysa (büyük/küçük harf duyarsız) bir sonraki boş `_n` adı seçilir. `move` `pending` (from, to, size, mtime) → `moveItem` → `{ref, state: done}`; hata → `{ref, state: failed, message}` ve `failed`'a `"Taşıma hatası: <localizedDescription>"`.
  - Bitiş: `plan.state = .applied`, `appliedRunID = runID`, kaydet. `applied` → `.alreadyApplied`; `inProgress` → `.notReady`.
  - `Recovery`: etkin durumu `pending` olan `move` → `to` var ve `from` yok → `done`, aksi `failed`. `pending` `undo` → ters kontrol (`from` var ve `to` yok → `done`, aksi `failed`). Düzeltilen satır sayısını döner.

- [ ] **Step 1: Write the failing tests**

```swift
struct JournalTests {
    @Test func appendsAndReadsBack() throws {
        let url = try TestFS.tempDir().appending(path: "r.jsonl")
        var j = try Journal.create(at: url, header: JournalEntry(seq: 0, type: "header", runID: "r-1"))
        let s = try j.append(JournalEntry(seq: -1, op: .move, state: .pending, from: "/a", to: "/b"))
        try j.append(JournalEntry(seq: -1, ref: s, state: .done))
        #expect(j.effectiveState(of: s) == .done)
        let reopened = try Journal.open(at: url)
        #expect(reopened.entries == j.entries)
        #expect(try String(contentsOf: url).split(separator: "\n").allSatisfy { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) != nil })
    }
}

struct ExecutorTests {
    // PlannerFixture (Task 10); plan Planner(useLLM: false) ile üretilir
    @Test func appliesApprovedOnly() async throws {
        // apply → screenshot hedefte, kaynakta yok; "download (3).pdf" yerinde (review); journal'da Ekran-Goruntuleri için mkdir + move done
        // plan.state == .applied, appliedRunID == summary.runID
    }
    @Test func refusesAppliedPlan() async throws { /* ikinci apply → #expect(throws: ExecutionError.alreadyApplied) */ }
    @Test func skipsChangedSource() async throws { /* plan sonrası kaynağa "ek" yaz → skipped reason "Kaynak değişmiş", dosya yerinde */ }
    @Test func skipsMissingSource() async throws { /* kaynağı sil → "Kaynak bulunamadı" */ }
    @Test func neverOverwritesExistingTarget() async throws {
        // plan sonrası hedef yoluna "orijinal" içerikli dosya koy → taşınan "_2" adına gider, mevcut dosya içeriği "orijinal" kalır
    }
    @Test func movesApprovedFolderWithContents() async throws {
        // "Album" (8 jpg + alt klasör "secilenler/1.jpg") → PlanEditor.bulkApprove(includeFolders: true) → apply
        // → Fotograflar/Album altında 8 jpg + secilenler/1.jpg; journal'da Album için TEK move satırı
    }
    @Test(.tags(.edgeCase)) func rerunAfterApplyFindsNothing() async throws {
        // apply sonrası yeni makePlan(useLLM: false) → hiçbir öğe approved değil; "Ekran-Goruntuleri" skipReason "Trimly kategori klasörü"
    }
    @Test func recoveryMarksPendingMoves() throws {
        // elle journal: move pending (dosya gerçekte `to`'da) → recover → effectiveState done
        // ikinci move pending (dosya `from`'da) → failed; recover dönüşü 2
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter "JournalTests|ExecutorTests"`.
- [ ] **Step 3: Implement** `Journal`, `Executor`, `Recovery`.
- [ ] **Step 4: Run tests** → geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): journaled executor with fsync and crash recovery"`

---

### Task 13: Undoer + RunLog

**Files:**
- Create: `Sources/TrimlyCore/Execution/Undoer.swift`
- Test: `Tests/TrimlyCoreTests/Execution/UndoerTests.swift`

**Interfaces:**
- Consumes: Task 12 `Journal`, `JournalEntry`, `Executor`, `SkippedEntry`
- Produces:
  - `struct UndoSummary: Sendable { let runID: String; let restored: Int; let removedFolders: Int; let skipped: [SkippedEntry] }`
  - `enum UndoError: Error, Equatable { case noRuns, runNotFound(String) }`
  - `struct Undoer { init(directory: DataDirectory); func undo(runID: String?) throws -> UndoSummary }` — `nil` → header `at`'ı en yeni ve tamamen geri alınmamış run.
  - `struct RunInfo: Sendable, Equatable { let runID: String; let planID: String; let root: String; let at: Date; let moved: Int; let undone: Bool }`; `enum RunLog { static func list(in: DataDirectory) throws -> [RunInfo] /* en yeni önce */ }`
- Kararlar (birebir sebepler):
  - Etkin durumu `done` olan `move`'lar ters seq sırasında, daha önce `done` bir `undo`'su olmayanlar: `SourceFingerprint.read(to)` nil → `"Hedefte dosya yok"`; journal'daki (size, mtime) ile `matches` false → `"Hedef dosya değişmiş"` (klasörde yalnızca varlık); `from` dolu → `"Orijinal konum dolu"`; aksi `undo` `pending` (`ref` = move seq) → `moveItem(to → from)` → `done`. Atlananlar için `undo` satırı `state: skipped`, `message` = sebep.
  - Sonra `mkdir`'ler ters sırada: klasör yalnızca `.DS_Store` içeriyorsa önce o silinir; boşsa `removeItem` + `undo done`; değilse `skipped` + `"Klasör boş değil"`.
  - İki kez çalıştırma güvenli: ikinci çağrı `restored == 0`, hata yok.
  - `RunInfo.moved` = etkin durumu `done` olan move sayısı; `undone` = her done move'un `done` undo'su var.

- [ ] **Step 1: Write the failing tests**

```swift
struct UndoerTests {
    @Test func undoRestoresAndRemovesCreatedFolders() async throws { /* apply → undo(nil) → screenshot orijinal adıyla kökte, Ekran-Goruntuleri yok, removedFolders == 1 */ }
    @Test func undoKeepsFolderWithForeignFiles() async throws { /* apply sonrası klasöre "yabanci.txt" → klasör kalır, skipped reason "Klasör boş değil" */ }
    @Test(.tags(.edgeCase)) func undoTreatsDSStoreOnlyFolderAsEmpty() async throws { /* apply sonrası klasöre ".DS_Store" → undo sonrası klasör yok */ }
    @Test func undoSkipsWhenTargetChanged() async throws { /* taşınan dosyaya "ek" → skipped "Hedef dosya değişmiş", dosya hedefte kalır */ }
    @Test func undoSkipsWhenOriginalOccupied() async throws { /* kaynak yoluna yeni dosya → skipped "Orijinal konum dolu" */ }
    @Test func undoRestoresFolderWithContents() async throws { /* önceki senaryo + undo → kökte Album tüm içeriğiyle, Fotograflar silinmiş */ }
    @Test func undoIsIdempotent() async throws { /* undo iki kez → ikinci restored == 0 */ }
    @Test func undoDefaultsToLatestRun() async throws { /* iki farklı kökte iki run; undo(nil) yalnız ikinciyi geri alır */ }
    @Test func runLogListsNewestFirst() async throws { /* RunLog.list → [run2, run1], moved sayıları, undo sonrası undone == true */ }
    @Test func undoWithoutRunsThrows() throws { /* boş veri dizini → #expect(throws: UndoError.noRuns) */ }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter UndoerTests`.
- [ ] **Step 3: Implement** `Undoer`, `RunLog`.
- [ ] **Step 4: Run full suite** — `swift test` → tüm testler geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): idempotent undo and run log"`

---

### Task 14: `trimly` CLI

**Files:**
- Modify: `Sources/trimly/Trimly.swift`
- Create: `Sources/trimly/PlanCommands.swift`, `RunCommands.swift`, `Output.swift`

**Interfaces:**
- Consumes: tüm `TrimlyCore` public API'si (Task 1–13)
- Produces (komutlar; her biri `--data-dir <yol>` seçeneği alır, başlangıçta `DataDirectory.ensureExists()` + `Recovery.recoverAll` + `SettingsStore.load`):
  - `trimly plan <klasör> [--no-llm]` — LLM açıksa önce `health()`: erişilemiyor → stderr `"Uyarı: Ollama erişilemiyor; yalnızca kurallar kullanılacak."`; `stage1Model` yüklü değil → `"Uyarı: <model> yüklü değil; yalnızca kurallar kullanılacak."`; her iki durumda `useLLM: false`. İlerleme stderr'e `LLM <processed>/<total>`. Çıktı: öğe tablosu (✓/✗ · durum · mevcut ad · → hedef (köke göre göreli) · güven · karar · sebep), ardından istatistik bloğu (`PlanStats` alanları Türkçe etiketlerle) ve son satır `Plan kaydedildi: <planID>`.
  - `trimly review <planID>` — `Planner.review`, aynı tablo + istatistik.
  - `trimly set <planID> <itemID> [--category <id>] [--name <aciklama>] [--approve | --reject]`
  - `trimly approve <planID> [--category <id>] [--reason <lowConfidence|llmError|weakRuleNoLLM|folder>] [--min-confidence <x>] [--folders]` — `"<n> öğe onaylandı (kritik öğeler toplu onaya dahil edilmez)."`
  - `trimly apply <planID> [--yes]` — özet: onaylı öğe sayısı, kritik onaylı öğeler ayrı liste; `--yes` yoksa `"Uygulansın mı? [e/H] "` (`e`, `evet`, `y`, `yes` kabul); sonra `RunSummary` (taşınan, atlanan + sebep, hatalı) ve `Geri almak için: trimly undo <runID>`.
  - `trimly undo [runID]` — `UndoSummary` basar.
  - `trimly runs` — `RunLog.list` tablosu.
  - `trimly settings [--path | --reset]` — varsayılan: mevcut ayarları JSON basar; `--path` dosya yolu; `--reset` varsayılanları yazar.
  - Hatalar stderr'e Türkçe mesaj, çıkış kodu 1 (ArgumentParser `ValidationError`/`ExitCode`).

- [ ] **Step 1: Write the smoke script**

`scripts/smoke.sh` (repo'ya eklenir):

```bash
#!/bin/zsh
set -euo pipefail
TMP=$(mktemp -d); ROOT="$TMP/root"; DATA="$TMP/data"; mkdir -p "$ROOT" "$DATA"
print '{"recentMinutes":0}' > "$DATA/settings.json"
print x > "$ROOT/Screenshot 2025-03-14 at 10.22.31.png"
print x > "$ROOT/cert.der"
BIN=.build/debug/trimly
PLAN=$($BIN plan "$ROOT" --no-llm --data-dir "$DATA" | tail -1 | sed 's/^Plan kaydedildi: //')
$BIN apply "$PLAN" --yes --data-dir "$DATA"
test -f "$ROOT/Ekran-Goruntuleri/2025-03-14_Ekran-Goruntusu_10-22-31.png"
test -f "$ROOT/cert.der"                       # kritik: onaysız, yerinde
$BIN undo --data-dir "$DATA"
test -f "$ROOT/Screenshot 2025-03-14 at 10.22.31.png" && test ! -d "$ROOT/Ekran-Goruntuleri"
echo "SMOKE OK"
```

- [ ] **Step 2: Run to verify failure** — `swift build && zsh scripts/smoke.sh` → başarısız (komutlar yok).
- [ ] **Step 3: Implement** CLI komutları ve `Output` biçimleyicileri.
- [ ] **Step 4: Run** — `swift build && zsh scripts/smoke.sh` → son satır `SMOKE OK`; `swift test` → tümü geçer.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(cli): plan/review/set/approve/apply/undo/runs/settings commands"`

---

### Task 15: Gerçek veriyle kabul ölçümü + kural iyileştirme

**Files:**
- Modify (gerekirse): `Sources/TrimlyCore/Rules/DefaultRules.swift`, `Settings.swift` varsayılan listeleri, ilgili testler
- Create: `docs/superpowers/reports/2026-11-21-phase1-real-data.md`

**Interfaces:**
- Consumes: Task 14 CLI. **Yalnızca `plan` çalıştırılır; `apply` gerçek veride çalıştırılmaz.**

- [ ] **Step 1: Release derle** — `swift build -c release` → `Compiling ... Build complete!`
- [ ] **Step 2: Kural-yalnız ölçüm** — `time .build/release/trimly plan ~/Downloads --no-llm` ve `~/Desktop` için aynısı. Beklenen: plan < 1 sn (spec §7), istatistik bloğu basılır.
- [ ] **Step 3: LLM'li ölçüm** — `time .build/release/trimly plan ~/Downloads` (Ollama açık). Kaydet: LLM'e giden sayı, toplam süre, öğe başı ortalama, `review` kırılımı, en sık 10 review deseni, `ollama ps` ile tepe bellek.
- [ ] **Step 3b: 2. aşama ölçümü** — Step 3'ün planı üzerinde `time .build/release/trimly review <planID>`; çalışırken `ollama ps` (ministral-3:14b bellek ve CPU/GPU dağılımı) ve `vm_stat` ile bellek baskısı kaydedilir. 16 GB'de swap'a düşüyorsa rapora `stage2Model` için daha küçük alternatif önerisi yazılır (`gemma3:4b` / `llama3.1`); ayar değişikliği kullanıcıya bırakılır.
- [ ] **Step 4: Rapor** — ölçümleri ve 5–10 örnek satırı (gizli/kişisel ad içerenler maskelenerek) rapora yaz.
- [ ] **Step 5: Kural iyileştirmesi (TDD)** — en sık review desenlerinden açıkça kurala bağlanabilenler için önce `RuleEngineTests`'e test ekle, sonra `DefaultRules`'ı güncelle, `swift test`, Step 2'yi tekrar çalıştırıp farkı rapora ekle. Tahmine dayalı/tartışmalı kurallar eklenmez, rapora öneri olarak yazılır.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "chore: phase 1 real-data measurement and rule tuning"`
- [ ] **Step 7: Kullanıcıya raporla** — istatistikler, süre, öneriler; gerçek veride `apply` için açık onay iste.
