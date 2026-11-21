# Trimly Faz 3 — İç İçe Tarama, Etiketler, Çöp Adayları

Tarih: 2026-11-21 · Durum: Onay bekliyor · Üst dokümanlar: `2026-11-21-trimly-design.md`, `2026-11-21-trimly-phase2-app-design.md`
(Finder Sync extension bu fazdan sonraya, "Faz 4"e kaydı.)

## 1. Amaç

Kullanıcının uygulamayı gerçek klasörlerde kullanırken istediği üç şey:

1. **İç içe tarama:** Alt klasörlerin içi de taranıp düzenlenebilsin; daha önce düzenlenmiş bir klasör, hedef
   değişince (ör. merkezi arşiv) yeniden düzenlenebilsin.
2. **Etiketler:** Trimly dosyalara Finder etiketi koyabilsin; mevcut Finder etiketlerine göre de düzenleyebilsin.
3. **Çöp adayları:** Gereksiz dosyalar işaretlensin ve kullanıcı bunları **tek tek** Çöp Kutusu'na gönderebilsin.

Her üçü de mevcut güvenlik ilkelerini korur: önizleme, açık onay, journal, geri alma, kritik dosya bariyeri.

## 2. Hedefler, hedef olmayanlar, anti-hedefler

**Hedefler**
- Derinlik sınırına kadar (varsayılan 3) tek planda iç içe tarama; klasör bazında "dağıt / bütün tut".
- Trimly kategori klasörlerinin içi de taranır (hedef değişince arşive taşıma, adlandırma değişince yeniden adlandırma).
- İsteğe bağlı "yalnızca boş kalan klasörleri kaldır".
- Taşınan dosyaya kategori etiketi ekleme; "Sadece etiketle" hedef modu; mevcut etiketlerden kategori çıkarma; etiket eşlemeleri.
- Çöp adayı kuralları; ayrı "Çöp adayları" bölümü; satır başına "Çöp Kutusu'na at"; geri alma.
- CLI karşılıkları (plan çıktısı, klasör modu, tek öğe çöp).

**Hedef olmayanlar**
- Çöp Kutusu'nu boşaltma / kalıcı silme. Toplu çöp atma (hiçbir arayüzde, çekirdekte de API yok).
- Görsel benzerlikle kopya bulma (yalnızca içerik özdeş kopyalar). Etiket renkleri.
- Derinlik sınırının ötesine inme; proje klasörlerinin içine inme.
- Finder Sync extension (Faz 4).

**Anti-hedefler**
- Kullanıcının satıra özel tıklaması olmadan tek bir dosyanın Çöp Kutusu'na gitmesi.
- Proje klasörünün (`.git`, `package.json` …) içindeki tek bir dosyaya dokunulması.
- Kritik bir öğenin çöp adayı olması, çöpe atılması veya otomatik onaylanması.
- Bir alt klasörün kullanıcı istemeden parçalanması (tek türden klasörler varsayılan olarak bütün kalır).
- Geri almanın sessizce başarısız olması (ör. Çöp boşaltılmışsa açıkça raporlanır).

## 3. Kısıtlar

- Mevcut mimari: `TrimlyCore` + `trimly` CLI + SwiftUI uygulama; Swift 6, macOS 14+, yeni dış bağımlılık yok.
- Finder etiketleri: `URLResourceValues.tagNames` (oku/yaz). Çöp: `FileManager.trashItem(at:resultingItemURL:)`.
- Tüm dosya işlemleri journal'lı ve `DataLock` altında; geri alma journal'ı tersten oynatır.
- `Plan.currentEngineVersion` her alt fazda artar (3a → 3, 3b → 4, 3c → 5): her biri sınıflandırmayı değiştirir, eski
  planlar yeniden kullanılmaz, yeniden taranır.

## 4. Yaklaşımlar

| # | Yaklaşım | Durum |
|---|---|---|
| **A (seçildi)** | Tek planda iç içe tarama; plan öğeleri ağaç bilgisi taşır, klasörlerde dağıt/bütün tut modu | Kullanıcı seçti: otomatik derin tarama, tek pencere |
| B | Klasör klasör inme ("İçini düzenle" ayrı plan penceresi açar) | Daha az değişiklik ama derinliğe elle inilir; elendi |

Etiketler ve çöp için tek makul yol var: aynı plan/journal/geri alma hattına yeni öğe alanları ve journal
işlemleri (`tag`, `trash`, `rmdir`) eklemek. Ayrı araçlar veya ayrı veri depoları güvenlik modelini böler.

**Teslim sırası (her biri ayrı plan + ayrı merge):** 3a İç içe tarama + boş klasörler → 3b Etiketler → 3c Çöp adayları.

## 5. Tasarım

### 5.1 Model değişiklikleri (TrimlyCore)

`FileItem` ek alanlar: `relativePath` (köke göre, ör. `Rastgele/alt/fatura.pdf`), `depth` (üst seviye 0),
`parentRelativePath: String?`, `finderTags: [String]`.

`PlanItem` ek alanlar:

| Alan | Anlam |
|---|---|
| `relativePath`, `depth`, `parentID: String?` | Ağaçtaki yer |
| `folderMode: FolderMode?` | Klasörlerde `keep` (bütün tut) / `distribute` (dağıt) |
| `covered: Bool` | Bir `keep` atasının içinde: taşınmaz, onaylanmaz, hedefi yok (klasörle birlikte gider) |
| `existingTags: [String]`, `tagsToAdd: [String]` | 3b |
| `trashReason: TrashReason?`, `trashedRunID: String?` | 3c |

`Settings` ek alanlar (varsayılanlar): `scanDepth = 3`, `distributeThreshold = 0.8`, `removeEmptyFolders = false`,
`addCategoryTags = true`, `tagMappings: [String: String] = [:]` (etiket → kategori kimliği),
`trashInstallerAgeDays = 30`, `trashPartialDownloadAgeDays = 1`, `trashDuplicates = true`, `trashEmptyFiles = true`,
`trashTempFiles = true`. `TargetMode` yeni durum: `tagOnly`.

`JournalOp` yeni işlemler: `rmdir`, `tag`, `trash`. `JournalEntry` ek alanlar: `tags: [String]?`, `previousTags: [String]?`.

### 5.2 Tarama (3a)

- `FolderScanner.scan(root:maxDepth:shouldDescend:)` ağacı derinlik sınırına kadar çıkarır. İnilmeyenler: semboliklinkler,
  paketler, gizli klasörler, **proje klasörleri** (her seviyede `IgnoreRules` proje kontrolü), derinlik sınırı.
- Güvenlik sınırı: en fazla 5.000 öğe. Aşılırsa daha derine inilmez ve plan penceresinde bir not gösterilir.
- Spotlight alanları ve Finder etiketleri her öğe için tek seferde okunur (Faz 1'deki gibi tek IPC).
- Klasör histogramı: klasörün derinlik içindeki tüm dosyaları (gizli ve proje alt ağaçları hariç).

### 5.3 Klasör modları ve kapsama (3a) — tek veri akışı

1. Tarama tüm ağacı plan öğelerine çevirir (her öğe `parentID` taşır).
2. Varsayılan mod:
   - **Trimly kategori klasörü** → her zaman `distribute`; klasörün kendisi asla taşınmaz.
   - Histogramda tek kategori ≥ `distributeThreshold` → `keep`.
   - Aksi halde `distribute` **önerisi**: klasör satırı karar bekleyene düşer (`reviewReason = .mixedFolder`).
3. `CoverageResolver.apply(&plan)` kökten aşağı yürür:
   - `keep` klasör etkin bir birimdir: kendisi taşınır, tüm alt öğeleri `covered = true` olur.
   - `distribute` klasörün kendisi taşınmaz (hedefi yok, onaylanamaz), çocukları etkin öğe olur.
4. `TargetAssigner` yalnızca etkin öğelere hedef verir; çakışma ekleri tüm plan için deterministik yeniden hesaplanır.
5. Mod değişince (`PlanEditor.setFolderMode`) yeniden tarama yapılmaz; 3–4 tekrar çalışır.
6. **Zaten yerinde olanlar:** `inPlace` modda kategori klasörlerinin içindeki dosyaların hedefi kendileriyse
   `TargetResolver.samePath` ile `skipped "Zaten düzenli"` olur. Hedef merkezi arşive dönerse veya adlandırma
   değişirse öneriler kendiliğinden çıkar. (Faz 2'deki "kategori klasörü atlanır" kuralı ve açıklama notu kalkar.)
7. Kritik kuralı her seviyede aynıdır; kapsanmış kritik bir dosya, `keep` klasörüyle birlikte taşınır. Böyle bir klasör
   satırında "içinde N kritik dosya var" uyarısı gösterilir ve klasör varsayılan olarak onaysız gelir.

### 5.4 LLM (3a)

- İç içe öğeler üst seviyedekilerle aynı hattan geçer (kesin kural → LLM yok; zayıf kural → LLM).
- `ClassificationRequest.relativePath` eklenir; istemde "Konum: Rastgele/alt/" satırı yer alır (üst klasör adları ipucudur).
- Klasör modu kararı LLM'e bırakılmaz; deterministik histogramdır.

### 5.5 Uygulama ve boş klasörler (3a)

- Executor yalnızca onaylı **etkin** öğeleri taşır; kapsanmış öğeler klasörleriyle gider.
- `removeEmptyFolders` açıksa taşımalardan sonra, içinden en az bir öğe taşınan kaynak klasörler en derinden
  başlayarak kontrol edilir: yalnızca `.DS_Store` kalmışsa o silinir; tamamen boşsa journal `rmdir` (pending) →
  `rmdir(2)` → done. Kök klasör asla kaldırılmaz. Boş olmayan klasöre dokunulmaz.
- Geri alma journal'ı tersten oynatır: `rmdir` geri alınırken klasör yeniden oluşturulur (üstten alta), sonra dosyalar
  eski yerlerine döner. Silinen `.DS_Store` **geri getirilmez** (Finder yeniden üretir).

### 5.6 Etiketler (3b)

- **Okuma / kural:** `RuleEngine`, ad kalıplarından önce etiketlere bakar. Etiket `tagMappings`'te varsa (büyük/küçük harf
  duyarsız) veya bir kategorinin klasör/etiket adıyla (TR/EN) eşleşiyorsa → kesin kategori (`descriptionHint` yok).
- **Yazma:** `addCategoryTags` açıksa, taşınan her dosyaya kategori etiketi (ayardaki dilde, ör. "Fatura") eklenir;
  mevcut etiketler korunur. Journal `tag` (path = son yol, `previousTags`, `tags`).
- **`tagOnly` modu:** hiçbir şey taşınmaz; onaylı öğelere yalnızca etiket eklenir. Plan satırında hedef yerine
  "＋ Fatura etiketi" gösterilir. `TargetAssigner` bu modda hedef üretmez; `tagsToAdd` doldurur.
- **Geri alma:** `tag` işlemi geri alınırken `previousTags` aynen geri yazılır (taşımadan önce, ters sırada).

### 5.7 Çöp adayları (3c)

- `TrashDetector` (`Settings`'e göre), her etkin dosya için en fazla bir `TrashReason`:
  - `oldInstaller(days)`: `.dmg .pkg .mpkg .iso .exe .msi`, eklenme/oluşturma tarihi `trashInstallerAgeDays`'ten eski.
  - `stalePartialDownload`: `.crdownload .part .download .opdownload`, `trashPartialDownloadAgeDays`'ten eski
    (daha yenileri bugünkü gibi "Yarım indirme" ile atlanır).
  - `duplicate(of: relativePath)`: aynı boyut (> 0) gruplarında SHA-256 akışlı özet; grupta "orijinal" = kopya eki
    (`(1)`, ` kopya`, ` copy`) olmayan en kısa ad, eşitse en eski; diğerleri kopya.
  - `emptyFile`: 0 bayt. `tempFile`: `.tmp`, `~$` ile başlayanlar, `Thumbs.db`.
- **Asla aday olmaz:** kritik öğeler, proje alt ağaçları, klasörler.
- Aday öğeler normal sınıflandırılır ama `approved = false` gelir ve "Çöp adayları" bölümünde gösterilir.
- **Tek öğe API'si (toplu yok):** `Executor.trash(planID:itemID:) async throws -> RunSummary` — kilit, parmak izi
  kontrolü, `trashItem`, journal `trash` (from, to = Çöp'teki yol) içeren tek işlemlik bir run, plan öğesine
  `trashedRunID`. Yalnızca `ready` planda çalışır (uygulanmış planda `alreadyApplied`); plan `ready` kalır.
  Kapsanmış öğeler (bir `keep` klasörün içindekiler) aday değerlendirmesine girmez.
- Geri alma: o run'ın `Undoer.undo(runID:)`'si dosyayı Çöp'ten eski yerine getirir; dosya Çöp'te yoksa
  "Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)" ile atlanır.

### 5.8 Arayüz

- **Satırlar:** köke göre kaynak yolu (`Rastgele/alt/fatura.pdf`) + hedef.
- **Karar bekleyen:** dağıtılan karışık klasörlerin öğeleri o klasörün başlığı altında gruplanır; klasör satırında
  "Dağıt / Bütün tut" seçici; `keep` klasör satırında kapsanan öğe sayısı ve varsa kritik uyarısı.
- **Çöp adayları bölümü:** sebep ("30 günden eski kurulum dosyası", "`fatura.pdf` ile aynı içerik") ve satır başına
  **"Çöp Kutusu'na at"**. Atılan satır "Çöp Kutusu'nda · Geri Al" olur. Bölümde toplu düğme yok.
- **Ayarlar:** Hedef sekmesine "Sadece etiketle", "Taşınan dosyalara kategori etiketi ekle", "Yalnızca boş kalan
  klasörleri kaldır", "Tarama derinliği". Yeni sekmeler: **Etiketler** (eşleme listesi: etiket → kategori seçici),
  **Çöp** (kural anahtarları ve gün eşikleri).

### 5.9 CLI

- `plan` çıktısı göreli yolları, klasör modlarını ve çöp adaylarını gösterir.
- `trimly set <plan> <item> --mode keep|distribute`.
- `trimly trash <plan> <item> [--yes]` — tek öğe; toplu biçimi yok.
- Etiket eşlemeleri ve çöp kuralları `settings.json` ile.

## 6. Test ve doğrulama

- Çekirdek: derinlik ve proje budama; histogram ve varsayılan modlar; kapsama (keep/distribute geçişleri, kritik
  her seviyede); kategori klasörü içinde "Zaten düzenli" ve merkezi arşive göç; boş klasör kaldırma + geri alma
  sırası (`.DS_Store` geri gelmez); etiket kuralı önceliği, etiket yazma ve geri alma, `tagOnly`; her çöp kuralı,
  kopya seçimi, kritik/proje hariç tutma, tek öğe çöp + geri alma, Çöp boşaltılmışsa raporlama.
- Uygulama: PlanSession'da mod değiştirme, gruplama, çöp satırı akışı, ayarlar.
- Elle: geçici klasörlerde iç içe yapı, etiketlerin Finder'da görünmesi, Çöp'e atma ve geri alma.

## 7. Kararlarım

- Teslim üç ayrı plan/merge: 3a → 3b → 3c.
- Kategori klasörleri artık taranır; "zaten düzenli" durumu hedef = kaynak kuralından çıkar.
- 5.000 öğe güvenlik sınırı.
- Kapsanmış kritik dosya klasörüyle taşınabilir, ancak klasör onaysız gelir ve uyarı gösterilir.
- Her çöp atma kendi küçük run'ı olur (öğe başına geri alma kolaylığı için); Geçmiş'te "Çöp: ad" olarak listelenir.
- Etiket kuralı ad kalıplarından önce gelir (kullanıcının bilinçli işareti).

## 8. Geliştiriciye bırakılanlar

Gruplu satırların SwiftUI bileşeni, çöp sebep metinlerinin son hali, kopya grubunda "orijinal" seçimindeki ince eşitlik
durumları, ayar sekmelerinin yerleşimi.
