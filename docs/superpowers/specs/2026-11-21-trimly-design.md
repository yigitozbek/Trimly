# Trimly — Tasarım Dokümanı

Tarih: 2026-11-21 · Durum: Onay bekliyor

## 1. Amaç ve neden

Mac'teki dağınık klasörleri (öncelik `~/Desktop` ve `~/Downloads`, ama Finder'da sağ tıklanan
herhangi bir klasör) **yerel** yapay zeka destekli, **güvenli** ve **düşük kaynak tüketen** bir
şekilde düzenleyen native macOS aracı. Hiçbir veri makineden çıkmaz; hiçbir dosya önizleme ve
onay olmadan taşınmaz; her uygulanan işlem tek aksiyonla geri alınabilir.

Ortam (2026-11-21 itibarıyla doğrulandı): M2 Pro, 16 GB RAM, Xcode 27.2, Swift 6.4,
Ollama 0.40.16 (`localhost:11434`, çalışıyor), yüklü modeller: `qwen3:4b`, `gemma3:4b`,
`llama3.1`, `ministral-3:14b`. Apple Development imza sertifikası mevcut (team `8FCFVBQ4LK`).
Desktop/Documents iCloud senkronizasyonu kapalı.

Örnek yük: `~/Downloads` üst seviyede 385 öğe (144 png, 29 mp4, 26 pdf, 16 json, 12 jpeg,
11 dmg, 8 `.app`, 7 sql, 5 `.der`, 31 klasör); `~/Desktop` 15 öğe.

## 2. Hedefler, hedef olmayanlar, anti-hedefler

**Hedefler**
- Finder sağ tık: klasörün üstünde **"Trimly ile Düzenle"**, klasör penceresinin veya
  masaüstünün boş alanında **"Trimly ile Burayı Düzenle"**.
- Katmanlı sınıflandırma: deterministik kurallar → (yalnızca belirsizler) yerel LLM 1. aşama →
  (yalnızca düşük güven / kritik, kullanıcı tetikler) LLM 2. aşama.
- Dry-run önizleme (`Mevcut ad → Hedef klasör / Yeni ad`, güven, sebep), satır bazında
  onay/düzenleme, uygula, journal, geri al.
- Ayarlar ekranı: **adlandırma formatı seçmeli** (kullanıcı kendi seçer), kategori dili, hedef
  modu, modeller, güven eşiği, LLM girdi seviyesi, hariç tutma listesi.
- Test ve otomasyon için CLI.

**Hedef olmayanlar (MVP)**
- Silme (hiçbir koşulda). Kopya (duplicate) tespiti. Arka planda otomatik izleme/düzenleme.
- Alt klasörlere özyinelemeli (recursive) yeniden düzenleme — yalnızca seçilen klasörün üst seviyesi.
- Görsel içerik analizi (vision). Bulut LLM'leri. App Store dağıtımı / notarization.
- Kullanıcının kendi adlandırma şablonunu token'larla yazması (preset'ler yeterli; sonra eklenebilir).

**Anti-hedefler** (teknik olarak çalışsa bile başarısızlık sayılır)
- Herhangi bir veri kaybı; var olan dosyanın üzerine yazma.
- Önizleme/onay olmadan tek bir dosyanın taşınması veya yeniden adlandırılması.
- Aktif proje klasörlerine (`.git`, `node_modules`, build çıktıları…) dokunulması.
- Kritik dosyalarda LLM'in tek başına karar vermesi veya bu dosyaların içeriğinin LLM'e gitmesi.
- Uygulamanın boştayken kaynak tüketmesi; modellerin bellekte süresiz kalması.

## 3. Kısıtlar

- macOS 14+ deployment target (geliştirme makinesi macOS 27). Sadece yerel kullanım.
- Tek dil: Swift. İzin verilen tek dış bağımlılık: Apple'ın `swift-argument-parser` paketi (CLI).
  Uygulama projesi üretimi için `XcodeGen` (yalnızca geliştirme aracı).
- LLM sağlayıcısı soyut bir protokol arkasında; ilk ve tek implementasyon Ollama HTTP API.
- Finder Sync extension sandbox'lı olmak zorunda; host uygulama sandbox'sız (Desktop/Downloads
  erişimi için TCC izin istemi beklenir).

## 4. Yaklaşımlar

| # | Yaklaşım | Artı | Eksi |
|---|---|---|---|
| **1 (seçildi)** | **Tamamen native Swift**: `TrimlyCore` kütüphanesi + CLI + SwiftUI uygulama + Finder Sync extension | Tek dil, ek runtime yok, en düşük kaynak; motor uygulama içinde in-process | Xcode projesi + imzalama; motor iterasyonu Python'dan biraz yavaş |
| 2 | Python motor + Swift kabuk (subprocess + JSON) | Motorda hızlı iterasyon | İki dil, sistem Python 3.9'a bağımlılık, dağıtım zor, iki test dünyası |
| 3 | Python + Automator Quick Action + localhost web arayüz | Xcode gerekmez | **Masaüstü boşluğuna sağ tık mümkün değil** (Quick Action yalnızca seçili öğede çıkar) — gereksinimi karşılamıyor |

Kullanıcı 1'i seçti. Masaüstü boş alanı için `FIFinderSync` container menüsü tek yol olduğundan
1 ve 2 Swift extension'ı zaten gerektiriyordu; 1 bunu tek dilde toplar.

## 5. Mimari

```
Finder sağ tık ─► TrimlyFinder (Finder Sync ext, sandbox)
                     │  NSWorkspace.open("trimly://organize?path=…")
                     ▼
               TrimlyApp (SwiftUI) ──────────┐       trimly CLI ───┐
                     │                        │                     │
                     └──────────► TrimlyCore (Swift package) ◄──────┘
                                   Scan → Ignore → Rules → LLM1 → (LLM2) → Naming → Plan
                                   Plan ─(onay)─► Executor ─► Journal (JSONL) ─► Undo
                                                    │
                                        Ollama HTTP (localhost:11434)
```

### 5.1 Depo yapısı

```
Trimly/
├── Package.swift                 # TrimlyCore (library), trimly (executable), TrimlyCoreTests
├── Sources/
│   ├── TrimlyCore/
│   │   ├── Model/       FileItem, Category, Plan, PlanItem, Settings
│   │   ├── Scan/        Scanner, MetadataReader (MDItem/Spotlight), ContentPreview
│   │   ├── Rules/       IgnoreRules, RuleEngine, DefaultRules, CriticalDetector
│   │   ├── LLM/         LLMProvider, OllamaProvider, PromptBuilder, ResponseSchema
│   │   ├── Naming/      Normalizer, DateResolver, NamingTemplate, TargetResolver
│   │   ├── Planning/    Planner (pipeline), PlanStore
│   │   └── Execution/   Journal, Executor, Undoer, Recovery
│   └── trimly/          CLI komutları
├── Tests/TrimlyCoreTests/
├── App/                          # Faz 2–3
│   ├── project.yml               # XcodeGen: TrimlyApp + TrimlyFinder, TrimlyCore'a bağlı
│   ├── TrimlyApp/
│   └── TrimlyFinder/
└── docs/
```

Veri dizini (uygulama ve CLI ortak): `~/Library/Application Support/Trimly/`
→ `settings.json`, `plans/<planId>.json`, `runs/<runId>.jsonl`. CLI ve testler `--data-dir` ile
değiştirebilir.

### 5.2 Tarama (Scan)

- Yalnızca seçilen kökün **üst seviyesi**. Symlink/alias takip edilmez (atlanır).
- Her öğe için `FileItem`: yol, ad, uzantı, dosya/klasör/paket, boyut (klasörde hesaplanmaz),
  oluşturulma/değiştirilme tarihi, UTType, Spotlight alanları: `kMDItemDateAdded`,
  `kMDItemWhereFroms` (indirme kaynağı), `kMDItemTitle`, `kMDItemAuthors`,
  `kMDItemContentCreationDate`.
- Klasör öğeleri için ek: ilk 20 çocuğun adı + uzantı histogramı (sınıflandırma ipucu).

### 5.3 Hariç tutma (Ignore) — çıktı: `skipped` + sebep

Varsayılanlar (ayarlardan değiştirilebilir):
- Gizli dosyalar (`.` ile başlayan), `.DS_Store`, `.localized`.
- `.app` paketleri.
- Yarım indirmeler: `.crdownload`, `.part`, `.download`, `.opdownload`.
- Son **60 dakikada** değişmiş öğeler.
- Proje klasörleri: içinde `.git`, `package.json`, `node_modules`, `Package.swift`, `*.xcodeproj`,
  `Cargo.toml`, `pyproject.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`,
  `composer.json`, `.venv`/`venv`, `Pods` varsa. Adı `build`, `dist`, `target`, `DerivedData`,
  `node_modules` olan klasörler.
- **Trimly'nin kendi kategori klasörleri** (kökte zaten var olan `Faturalar/` vb. yeniden taşınmaz).
- Kullanıcının glob listesi.

### 5.4 Kural motoru (Rules)

Her kural `RuleMatch(category, strength, critical, descriptionHint?)` döndürür.
`strength`: `.decisive` (LLM çağrılmaz) veya `.weak` (LLM varsa ona gider; rule'un tahmini ipucu
ve LLM yoksa/başarısızsa yedek olur). Öncelik sırası: dosya adı kalıpları → uzantı haritası →
klasör histogramı.

- Decisive eşleşme → `status: ready`, `confidence: 1.0`, `decidedBy: rule`.
- Weak eşleşme LLM'siz kalırsa (`--no-llm`, Ollama yok, LLM hatası) → kategori dolu,
  `confidence: 0.6` → eşik altı olduğu için `review`; kullanıcı toplu onaylayabilir.
- Ekran görüntüsü/kaydı kalıplarında açıklama = adın saat kısmı (`10-22-31`); `IMG_4821` gibi
  adlarda açıklama = normalize gövde (`IMG-4821`).

- **Ad kalıpları** (decisive): `Screenshot YYYY-MM-DD at …`, `Ekran Resmi …`,
  `Ekran Görüntüsü …` → Ekran-Goruntuleri; `Screen Recording …`, `Ekran Kaydı …` →
  Ekran-Kayitlari; `IMG_\d+`, `PXL_…`, `WhatsApp Image …` + HEIC/JPG → Fotograflar;
  `fatura|invoice|e-arsiv|e-fatura` → Faturalar; vb.
- **Uzantı haritası**: görsel/video/ses/arşiv/kurulum/kod/tasarım/yazı tipi/e-kitap → decisive;
  `pdf, docx, doc, txt, md, rtf, pages, json, csv, xlsx, zip` → **weak** (kategori veya açıklama
  belirsiz; LLM'e gider).
- **Klasör**: uzantı histogramında tek kategori ≥%70 ise weak eşleşme, değilse LLM. Klasör
  öğeleri önizlemede **varsayılan onaysız** gelir.
- **Kritik tespit** (`CriticalDetector`): uzantı (`der, pem, cer, key, p12, pfx, mobileprovision,
  env, sql, sqlite, db, kdbx, udf`) veya ad anahtar kelimesi (`kimlik, nufus, pasaport, tc,
  ehliyet, saglik, rapor, recete, tahlil, bordro, maas, iban, sifre, password, vekaletname`).
  Kritik öğe: içeriği LLM'e gitmez, 2. aşamada da yalnızca ad+metadata.
- **Kritik onay bariyeri**: kritik öğenin `approved` alanını hiçbir otomatik adım (kural, LLM1,
  LLM2, toplu onay) `true` yapamaz; yalnızca o öğeye özel açık kullanıcı aksiyonu yapabilir
  (UI'da satır onay kutusu, CLI'da `trimly set <plan> <item> --approve`). LLM yalnızca kategori/ad
  **önerisi** doldurur; `status` `critical` olarak kalır.

### 5.5 LLM sınıflandırıcı

```swift
protocol LLMProvider: Sendable {
    func classify(_ request: ClassificationRequest, model: String) async throws -> ClassificationResult
    func unload(model: String) async
    func health() async -> ProviderHealth   // erişilebilir mi, model yüklü mü
}
```

- `OllamaProvider`: `POST /api/chat`, `stream: false`, `think: false`,
  `options: { temperature: 0, num_ctx: 4096 }`, `keep_alive: "2m"`, `format` = aşağıdaki şema.
  Timeout 60 sn, 1 yeniden deneme.
- **Şema** (`target_folder` enum'u ayarlardaki kategori listesinden üretilir — model uydurma
  klasör adı döndüremez):

```json
{
  "type": "object",
  "properties": {
    "target_folder":  { "type": "string", "enum": ["Belgeler", "Faturalar", "…", "Diger"] },
    "suggested_name": { "type": "string", "description": "2-6 kelimelik kisa aciklama; tarih, kategori ve uzanti YOK" },
    "confidence":     { "type": "number", "minimum": 0, "maximum": 1 },
    "reason":         { "type": "string", "maxLength": 160 }
  },
  "required": ["target_folder", "suggested_name", "confidence", "reason"],
  "additionalProperties": false
}
```

- `suggested_name` yalnızca **açıklama** kısmıdır; tarih/kategori/uzantıyı uygulama, seçili
  adlandırma şablonuyla kendisi birleştirir (LLM format bilmez).
- **`DescriptionSanitizer`** (deterministik, şablondan önce): şema yapıyı garanti eder, içeriği
  etmez — 4B modeller açıklamaya tarih/uzantı/kategori sızdırabilir. Sırayla: sondaki uzantıları
  (orijinal + bilinen uzantılar) at → tarih kalıplarını at (`YYYY-MM-DD`, `DD.MM.YYYY`,
  `YYYYMMDD`, `YYYY_MM_DD`, TR/EN ay adı + yıl) → baştaki/sondaki kategori klasör/etiket adlarını
  (TR+EN) ve dolgu kelimeleri (`dosya, file, belge, document, yeni, new, kopya, copy`) at →
  normalize → kelime sınırında 50 karaktere kes. Sonuç boş veya 2 karakterden kısaysa sıradaki
  açıklama kaynağına düşülür. `reason` kodda 160 karaktere kesilir (Ollama'nın `maxLength`
  uygulamasına güvenilmez); dili denetlenmez, yalnızca gösterim içindir.
- **Girdi** (kullanıcı mesajı): ad, uzantı, boyut, tarihler, UTType, indirme kaynağının
  host+path'i (query string atılır), Spotlight başlık/yazar, kuralın ipucu, ve ayar açıksa ve öğe
  kritik değilse **içerik önizlemesi**: düz metin türlerinde ilk 1.500 karakter; PDF'te ilk sayfa
  metni (PDFKit); docx/rtf/doc'ta `NSAttributedString` ile ilk 1.500 karakter. Hepsi in-process,
  ek araç yok.
- Doğrulama: decode hatası, enum dışı değer, timeout → öğe `review` durumuna düşer, sebep
  "LLM yanıtı geçersiz".
- **Parti (batch)**: öğe başına bir istek, eşzamanlılık 1 (kaynak düşük kalsın). Parti = ilerleme
  ve checkpoint birimi (varsayılan 10): her parti sonrası plan diske yazılır; kesilirse `plan`
  kaldığı yerden devam eder.
- **1. aşama** `qwen3:4b`. `confidence < eşik (0.75)` → `review`.
- **2. aşama** (ayrı komut/buton, yalnızca `review` + kritik öğeler): `ministral-3:14b`, içerik
  önizlemesi 4.000 karakter / PDF ilk 2 sayfa. 2. aşama başlamadan 1. aşama modeli
  `keep_alive: 0` ile boşaltılır (16 GB RAM).

### 5.6 Adlandırma

- **Şablon preset'leri** (Ayarlar › Adlandırma, radyo düğmesi + canlı örnek):
  1. `YYYY-MM-DD_Kategori_Aciklama` (varsayılan)
  2. `Kategori_Aciklama`
  3. `YYYY-MM-DD_Aciklama`
  4. Orijinal ad (yalnızca normalize)
  5. Adı hiç değiştirme
- **Açıklama kaynağı** (her biri `DescriptionSanitizer`'dan geçer, boş kalırsa sıradakine düşer):
  LLM'in `suggested_name`'i → kuralın ipucu → orijinal adın gövdesi.
- **Kategori etiketi**: her kategorinin klasör adı (çoğul) ve dosya adındaki etiketi (tekil)
  ayrı tanımlıdır: `Faturalar/2025-02-10_Fatura_Enerjisa-Ocak.pdf`.
- **Tarih önceliği** (`DateResolver`): dosya adındaki tarih → `kMDItemContentCreationDate`
  (EXIF dahil) → oluşturulma (birthtime) → değiştirilme (mtime).
- **Normalize**: `ç→c ğ→g ı→i İ→I ö→o ş→s ü→u` (büyük harfler dahil), diğer aksanlar
  ASCII'ye katlanır, boşluk ve `_` → `-` (alt çizgi yalnızca şablon ayırıcısı), izin verilen
  `[A-Za-z0-9-]`, ardışık `-` teke iner, açıklama en fazla 50 karakter, uzantı küçük harf.
- **Klasör öğeleri**: kategori klasörüne birim olarak taşınır, adı yalnızca normalize edilir
  (şablon uygulanmaz).

### 5.7 Hedef yol ve çakışma

- **Hedef modu**: `inPlace` (varsayılan) → `<kök>/<Kategori>/<ad>`; `central` →
  `<arşiv>/<Kategori>/<ad>` (varsayılan arşiv `~/Documents/Arsiv`). `yearSubfolders` açıksa
  araya `<YYYY>/` eklenir (varsayılan kapalı).
- Çakışma (disk + aynı plan içindeki diğer öğeler, **büyük/küçük harf duyarsız** — APFS):
  `ad_2.ext`, `ad_3.ext`… Hedef = kaynak ise öğe `skipped` ("zaten düzenli").
- `review` durumundaki öğeler taşınmaz; kullanıcı elle kategori seçerse `ready` olur.

### 5.8 Plan

```json
{
  "id": "2026-11-21T14-03-22_Downloads",
  "root": "/Users/…/Downloads",
  "settingsSnapshot": { "…": "…" },
  "items": [{
    "id": "a1b2",
    "source": "/Users/…/Downloads/download (3).pdf",
    "kind": "file",
    "category": "Faturalar",
    "target": "/Users/…/Downloads/Faturalar/2025-02-10_Fatura_Enerjisa-Ocak.pdf",
    "confidence": 0.91,
    "reason": "Fatura no ve tutar içeriyor",
    "decidedBy": "llm1",
    "status": "ready",
    "critical": false,
    "approved": true,
    "sourceFingerprint": { "size": 48213, "mtime": "2025-02-10T09:12:00Z" }
  }]
}
```

- Plan seviyesinde `state: inProgress | ready | applied` ve `appliedRunId`. `applied` bir plan
  tekrar uygulanamaz. Aynı kök için 24 saatten yeni bir `inProgress` plan varsa `plan` onu
  sürdürür (sınıflandırılmış öğeler korunur, kalanlar işlenir).
- `status`: `ready | review | skipped | critical`. `review` öğelerinde
  `reviewReason: lowConfidence | llmError | weakRuleNoLLM | folder` (UI'da filtrelenebilir). `decidedBy`: `rule | llm1 | llm2 | manual`.
- Varsayılan `approved`: yalnızca `ready` + kritik değil + dosya (klasör değil) ise `true`.

### 5.9 Uygulama (Apply), journal ve geri alma (Undo)

- `apply <plan>`: yalnızca `approved: true` öğeler. Önce her öğenin `sourceFingerprint`'i ve
  hedefin boşluğu yeniden doğrulanır; değişmişse öğe atlanır ve raporlanır.
- **Journal** `runs/<runId>.jsonl`, append-only, her satır `fsync`:

```jsonl
{"seq":0,"type":"header","runId":"r-20261121-140501","planId":"…","root":"…","at":"…"}
{"seq":1,"op":"mkdir","path":"…/Faturalar","state":"done"}
{"seq":2,"op":"move","from":"…/download (3).pdf","to":"…/Faturalar/2025-02-10_Fatura_Enerjisa-Ocak.pdf","size":48213,"mtime":"…","state":"pending"}
{"seq":3,"ref":2,"state":"done"}
```

- Sıra: `pending` yaz → `FileManager.moveItem` (hedef varsa hata verir = üzerine yazmaz;
  yarışta yeni ekle yeniden denenir) → `done` yaz. Oluşturulan klasörler `mkdir` olarak
  kaydedilir.
- **Kurtarma**: açılışta/komut başında `pending` kalmış satırlar: dosya `to`'da ve `from` boşsa
  `done`, aksi halde `failed` işaretlenir.
- **Undo** `undo [runId]` (varsayılan son run): ters sırayla; dosya `to`'da ve boyut/mtime
  eşleşiyor ve `from` boşsa geri taşır; değilse atlar ve raporlar. Sonra Trimly'nin oluşturduğu
  klasörleri yalnızca **boşsa** siler. Undo adımları aynı journal'a `undo` op'u olarak yazılır →
  kısmi undo kaldığı yerden devam eder, iki kez çalıştırmak güvenlidir.
- Journal ve planlar süresiz saklanır (küçük dosyalar).

### 5.10 Ayarlar (`settings.json`, uygulama ve CLI ortak)

| Grup | Alanlar (varsayılan) |
|---|---|
| Adlandırma | `namingPreset` (1), `categoryLanguage` (`tr`) |
| Hedef | `targetMode` (`inPlace`), `archiveRoot` (`~/Documents/Arsiv`), `yearSubfolders` (false) |
| Model | `llmEnabled` (true), `providerURL`, `stage1Model` (`qwen3:4b`), `stage2Model` (`ministral-3:14b`), `confidenceThreshold` (0.75), `batchSize` (10), `contentPreview` (true), `timeoutSeconds` (60), `keepAlive` (`2m`) |
| Hariç tutma | `ignoreHidden`, `ignoreApps`, `recentMinutes` (60), `projectMarkers`, `ignoreGlobs` |
| Kritik | `criticalExtensions`, `criticalKeywords` |
| Kategoriler | liste: `id`, `folder.tr/en`, `tag.tr/en` (UI'da düzenleme MVP dışı; JSON'dan düzenlenir) |

**Varsayılan kategoriler** (TR klasör / etiket): Ekran-Goruntuleri/Ekran-Goruntusu,
Ekran-Kayitlari/Ekran-Kaydi, Fotograflar/Fotograf, Gorseller/Gorsel, Videolar/Video, Ses/Ses,
Belgeler/Belge, Faturalar/Fatura, Sozlesmeler/Sozlesme, Resmi-Evrak/Evrak, Saglik/Saglik,
Kitaplar-Makaleler/Kitap, Tablolar/Tablo, Sunumlar/Sunum, Veri/Veri, Kod/Kod, Tasarim/Tasarim,
Arsivler/Arsiv, Kurulum-Dosyalari/Kurulum, Sertifika-Anahtar/Sertifika, Yazi-Tipleri/Yazi-Tipi,
Diger/Diger. EN karşılıkları aynı listede.

### 5.11 CLI (Faz 1)

```
trimly plan <klasör> [--no-llm] [--data-dir …]   # tarar, sınıflandırır, tablo basar, planı yazar
trimly review <planId>                             # 2. aşama
trimly set <planId> <itemId> [--category X] [--name "aciklama"] [--approve|--reject]
                                                   # elle karar: hedefi yeniden hesaplar, decidedBy=manual
trimly approve <planId> [--category X] [--reason R] [--min-confidence 0.8] [--folders]
                                                   # toplu onay; kritik öğeleri ASLA kapsamaz
trimly apply <planId>                              # özet + [e/H] onayı, sonra uygular
trimly undo [runId]
trimly runs                                        # geçmiş
trimly settings [--path | --reset]
```

Onay CLI'da `set`/`approve` komutlarıyla (veya plan JSON'undaki `approved` alanını elle
düzenleyerek) yapılır. `plan` sonunda istatistik basar: toplam, decisive kural oranı, LLM'e
gidenler, `review` sayısı `reviewReason` kırılımıyla, kritik sayısı, en sık review'a düşen
ilk 10 uzantı/ad kalıbı. `apply` özeti kritik öğeleri ayrı listeler ve son interaktif onay ister.

### 5.12 SwiftUI uygulama (Faz 2)

- `trimly://organize?path=<percent-encoded>` URL şemasını karşılar → pencereyi açar ve taramayı
  başlatır. Motor in-process (`TrimlyCore`), Swift concurrency ile iptal edilebilir.
- **Önizleme penceresi**: araç çubuğu (klasör, Tara, ilerleme, "Detaylı incele (n)", "Uygula");
  tablo sütunları: ✓ · Mevcut ad · → Hedef klasör / Yeni ad (satır içi düzenlenebilir) ·
  Kategori (picker) · Güven · Kaynak (Kural/LLM/LLM2/Elle) · Sebep. Filtre sekmeleri:
  Hazır / İnceleme / Kritik / Atlanan.
- **Toplu onay**: kategori başlığında "tümünü seç", filtre bazlı "görünenleri onayla". Kritik
  satırlar kilit simgesiyle ayrışır ve toplu seçimden her zaman hariçtir.
- **Geçmiş**: run listesi + "Geri Al".
- **Ayarlar** (⌘,): sekmeler Adlandırma (radyo + canlı örnek), Hedef, Model (Ollama sağlık
  durumu göstergesi), Hariç tutma.
- Son pencere kapanınca uygulama kapanır (arka planda kaynak tüketmez). Ollama erişilemezse
  kurallar yine çalışır, LLM gerektirenler `review`'a düşer ve bir uyarı gösterilir.

### 5.13 Finder Sync extension (Faz 3)

- `FIFinderSync` alt sınıfı; `directoryURLs = [home]` (Desktop, Downloads ve tüm kullanıcı
  klasörleri kapsanır).
- `menu(for: .contextualMenuForItems)`: seçim tek klasörse **"Trimly ile Düzenle"** (o klasör).
- `menu(for: .contextualMenuForContainer)`: **"Trimly ile Burayı Düzenle"** (`targetedURL()`,
  masaüstü boş alanında `~/Desktop`).
- Aksiyon yalnızca `NSWorkspace.shared.open(trimly://…)`; extension dosyalara erişmez
  (entitlement: yalnızca `app-sandbox`).
- İlk açılışta uygulama, extension kapalıysa
  `FIFinderSyncController.showExtensionManagementInterface()` ile açma ekranını gösterir.
- Derleme: XcodeGen `project.yml` → `TrimlyApp` (sandbox'sız) + `TrimlyFinder` (app-extension,
  sandbox'lı), Apple Development imzası, `~/Applications`'a kurulum.

## 6. Fazlar

1. **Faz 1 — Çekirdek + CLI** (kullanıcının ilk istediği adım): tarama, hariç tutma, kural
   motoru, Ollama JSON sınıflandırıcı, adlandırma, plan, apply/journal/undo, kurtarma, CLI.
   Gerçek `~/Downloads` üzerinde `plan` çalışır; apply/undo testleri geçici dizinlerde.
   **Kabul kriteri**: gerçek `~/Downloads` üzerinde `plan --no-llm` ve `plan` (LLM'li)
   çalıştırılıp istatistikler raporlanır; en sık review'a düşen kalıplar için kural/normalize
   iyileştirmesi yapılır. (`plan` salt okunurdur; gerçek veride `apply` kullanıcı onayı olmadan
   çalıştırılmaz.)
2. **Faz 2 — SwiftUI uygulama**: önizleme, ayarlar (adlandırma seçimi dahil), geçmiş/undo,
   URL şeması.
3. **Faz 3 — Finder Sync extension** + kurulum/onboarding. İlk iş ayrı, atılabilir bir spike:
   (a) masaüstü boş alanında container menüsü, (b) Finder penceresi boş alanında container
   menüsü, (c) klasör üstünde item menüsü, (d) `trimly://` ile host uygulamanın doğru yolla
   açılması, (e) extension etkinleştirme + TCC izin akışı. Onboarding spike sonucuna göre
   şekillenir. **(a) çalışmazsa yedek**: klasörler için Quick Action (Services) + uygulama
   menüsünde/Dock menüsünde "Masaüstünü Düzenle" / "İndirilenleri Düzenle" kısayolları.

Her faz kendi uygulama planıyla ilerler; ilk plan yalnızca Faz 1'i kapsar.

## 7. Kalite ve performans hedefleri

- Testler: Swift Testing; dosya sistemi testleri geçici dizinde; `LLMProvider` mock'lanır;
  gerçek Ollama entegrasyon testi `TRIMLY_OLLAMA_TESTS=1` ile açılır.
- Kritik test senaryoları: normalize (TR karakterler), `DescriptionSanitizer` (tarih/uzantı/
  kategori sızıntısı, boş sonuçta yedeğe düşme), kritik öğenin hiçbir otomatik yolla (LLM2, toplu
  onay) onaylanamaması, tarih önceliği, çakışma soneki (büyük/küçük
  harf), proje klasörü atlama, kritik dosya içeriğinin prompt'a girmemesi, apply sırasında kaynak
  değişmişse atlama, yarıda kesilmiş apply'ın kurtarılması, undo'nun idempotent olması, hedef
  doluysa undo'nun atlaması.
- 400 öğelik klasörde kural-yalnız plan < 1 sn. Boştaki uygulama < 60 MB RAM. LLM eşzamanlılığı 1.

## 8. Riskler

- **Masaüstü boş alan menüsü**: `FIFinderSync` container menüsünün masaüstünde görünmesi
  beklenen davranış; Faz 3 başında spike ile doğrulanacak, yedek plan Faz 3'te tanımlı.
- **İnceleme kalabalığı**: ilk çalıştırmada Downloads'ta ~90 öğe review/kritik bekleniyor
  (klasörler, pdf/json/zip, kritikler). Toplu onay + Faz 1 ölçümüne göre kural iyileştirmesi.
- **Küçük model güven skoru** kalibre değil: eşik ayarlanabilir; 2. aşama ve elle onay güvenlik ağı.
- **TCC izinleri**: CLI, çalıştığı terminalin Desktop/Downloads iznini devralır; uygulama ilk
  erişimde izin ister.

## 9. Kararlarım (kullanıcının açıkça söylemediği, benim seçtiğim)

- Hedef modu varsayılanı `inPlace` ("burayı düzenle" mantığı), merkezi arşiv ayardan.
- `İnceleme` öğeleri taşınmaz, yerinde kalır; ayrı bir İnceleme klasörü yok.
- Klasör öğeleri birim olarak taşınır, adı yalnızca normalize edilir, varsayılan onaysız.
- `.app` paketleri varsayılan hariç.
- Öğe başına bir LLM isteği, eşzamanlılık 1; "batch" = checkpoint birimi.
- LLM yalnızca açıklama üretir; adı şablon birleştirir.
- Weak kural LLM'siz kalırsa `confidence 0.6` ile `review`'a düşer (kategori önceden dolu).
- Ekran görüntüsü açıklaması saat kısmı; anlamsız kamera adlarında normalize gövde.
- Yarıda kalan plan 24 saat içinde aynı kökte otomatik sürdürülür; uygulanmış plan tekrar uygulanmaz.
- CLI'da elle karar için `trimly set` komutu (JSON düzenlemeye gerek kalmaz).
- Kategori klasörleri ASCII (`Ekran-Goruntuleri`), çoğul klasör / tekil etiket.
- Proje üretimi için XcodeGen; CLI için `swift-argument-parser`.

## 10. Geliştiriciye bırakılanlar

Modüller arası iç arayüzlerin detayı, kural regex'lerinin tam listesi, prompt metni,
SwiftUI yerleşim detayları, CLI tablo çıktısının biçimi, hata mesajlarının metni.
