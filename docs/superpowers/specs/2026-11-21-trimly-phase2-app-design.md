# Trimly Faz 2 — SwiftUI Uygulaması Tasarımı

Tarih: 2026-11-21 · Durum: Onay bekliyor · Üst doküman: `2026-11-21-trimly-design.md` (§5.12)

## 1. Amaç

Faz 1'deki `TrimlyCore` motorunun üstüne native bir Mac uygulaması: bir klasörü tarar, önizlemeyi
gösterir, kullanıcı karar verir, "Uygula" ile journal'lı taşıma yapar, geçmişten geri alır. Ayarlar
(seçmeli adlandırma formatı dahil) uygulamadan değiştirilir. `trimly://organize?path=` ile dışarıdan
açılabilir; Faz 3'teki Finder menüsü bunu kullanacak. CLI ve uygulama aynı motoru ve aynı veri
dizinini paylaşır; davranışları ayrışmaz.

## 2. Hedefler, hedef olmayanlar, anti-hedefler

**Hedefler**
- Açılış penceresi: "Masaüstü", "İndirilenler", "Klasör seç…" kısayolları; son 5 işlem ve "Geri Al";
  Ollama durum göstergesi.
- Plan penceresi (klasör başına bir pencere), **karar bekleyenler önde** düzeni (bkz. §5).
- Uygula onay sayfası ve sonuç sayfası (geri al dahil).
- Geçmiş penceresi: tüm işlemler, işlem başına "Geri Al".
- Ayarlar (⌘,): Adlandırma, Hedef, Model, Hariç tutma sekmeleri; değişiklik anında `settings.json`'a.
- `trimly://organize?path=<percent-encoded>` URL şeması.
- Dock menüsü: "Masaüstünü Düzenle", "İndirilenleri Düzenle" (Faz 3 yedeği).
- Faz 1 incelemesinden ertelenen ve uygulama+CLI birlikteliğinde önem kazanan çekirdek düzeltmeleri (§6).

**Hedef olmayanlar**
- Finder Sync extension (Faz 3). Kategori listesini düzenleme arayüzü. Özel adlandırma token'ları.
- Arayüzün İngilizce yerelleştirmesi (arayüz Türkçe; kategori dili ayarı zaten var).
- App Store / notarization / otomatik güncelleme / menü çubuğu uygulaması. UI testleri.

**Anti-hedefler**
- Tarama/LLM sırasında arayüzün donması.
- "Uygula" ve onay sayfası olmadan tek bir dosyanın taşınması.
- Kritik satırın toplu işlemle onaylanabilmesi.
- Pencereler kapandıktan sonra uygulamanın arka planda kalması.
- Uygulama ve CLI'nin aynı plan/journal üzerinde birbirini bozması.

## 3. Kısıtlar

- macOS 14+ deployment target, Xcode 27.2, Swift 6 strict concurrency.
- Proje XcodeGen ile üretilir (`App/project.yml`, `/opt/homebrew/bin/xcodegen` mevcut); `.xcodeproj`
  repoya girmez (`.gitignore`), `xcodegen generate` ile üretilir.
- Uygulama sandbox'sız (Desktop/Downloads erişimi için TCC izni istenir), Apple Development imzası
  (team `UBF7FMWA6S`), otomatik imzalama, bundle id `app.trimly.Trimly`.
- Tek dış bağımlılık yok: uygulama yalnızca `TrimlyCore` (yerel paket) ve sistem framework'leri kullanır.
- Proje skill'leri: `swiftui-pro` (her tür kendi dosyasında, UIKit yok, erişilebilirlik etiketleri,
  modern API), `swift-concurrency-pro`, `swift-testing-pro`.

## 4. Yaklaşımlar

| # | Yaklaşım | Durum |
|---|---|---|
| **1 (seçildi)** | XcodeGen projesi + SwiftUI + `@Observable` view model'ler + in-process `TrimlyCore` | Ana tasarımda zaten karara bağlıydı; Faz 3 extension'ı aynı projeye eklenir |
| 2 | SwiftPM executable'ı elle `.app` paketine sarmak | Finder extension barındıramaz, Info.plist/URL şeması elle; elendi |
| 3 | AppKit (NSTableView/NSOutlineView) arayüz | Daha çok kod, swiftui-pro yönüne ters; elendi |

**Ana pencere düzeni** için iki seçenek değerlendirildi: (A) tasarımdaki tek tablo + filtre sekmeleri,
(B) karar bekleyenler önde, hazırlar kategori başlıklarında kapalı. Gerçek Downloads verisinde 388
öğenin 316'sı hazır, ~49'u karar bekliyor; A'da bu 49 öğe 316 satır arasında kayboluyor. Kullanıcı
kararı bana bıraktı; **B seçildi** (benim kararım).

## 5. Uygulama tasarımı

### 5.1 Pencereler ve sahneler

- `Window("Trimly", id: "start")` — açılış penceresi (uygulama ikonuna tıklanınca).
- `WindowGroup(id: "plan", for: URL.self)` — klasör başına plan penceresi; aynı klasör ikinci kez
  açılırsa mevcut pencere öne gelir (SwiftUI değer tekilleştirmesi).
- `Window("Geçmiş", id: "history")`.
- `Settings { SettingsView() }` — ⌘,.
- `onOpenURL` → `trimly://organize?path=…` çözülür; yol mevcut bir klasör değilse uyarı, değilse plan
  penceresi açılır ve tarama başlar. Bilinmeyen host/eksik `path` → uyarı.
- `NSApplicationDelegateAdaptor`: `applicationDockMenu` ("Masaüstünü Düzenle", "İndirilenleri
  Düzenle"), `applicationShouldTerminateAfterLastWindowClosed → true`.
- **URL ile açılış**: uygulama kapalıyken `trimly://` ile başlatılırsa açılış penceresi gösterilmez,
  yalnızca plan penceresi açılır (macOS 15+'ta `defaultLaunchBehavior(.suppressed)`, macOS 14'te
  açılış penceresini plan penceresi göründükten **sonra** kapatmak). Hiçbir an sıfır pencereli bir
  ara durum oluşmamalı; aksi halde "son pencere kapandı" kuralı uygulamayı erken sonlandırır.
- Plan penceresi kapanınca tarama/LLM görevi iptal edilir; Planner'ın checkpoint'i korunur.

### 5.2 Plan penceresi (düzen B)

```
┌ Downloads ───────────────────── [🔍 ara] [⟳ Yeniden tara] [Detaylı incele (12)] [Uygula (316)] ┐
│ ⚠ Ollama erişilemiyor — yalnızca kurallar kullanıldı.                         (gerekirse banner) │
│ ▼ Karar bekleyen (49)                                                                      │
│   🔒 kimlik.pdf            → Resmi-Evrak/2025-…_Evrak_Kimlik.pdf  [Kategori ▾] [açıklama] ☐  │
│   ?  download (3).pdf      → Belgeler/2025-…_Belge_Download-3.pdf [Kategori ▾] [açıklama] ☐  │
│   📁 Album                 → Gorseller/Album                                               ☐  │
│      sebep: LLM'siz zayıf kural · güven 0.60 · karar: kural                                  │
│ ▼ Hazır (316)                                                    [Tümünü kaldır / seç]     │
│   ▶ Fotograflar 107  ☑      ▶ Gorseller 71 ☑      ▶ Videolar 32 ☑   …                     │
│ ▶ Atlanan (23)   proje klasörü 12 · uygulama 8 · sistem 2 · gizli 1                          │
└───────────────────────────────────────────── LLM 40/107 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ [İptal] ┘
```

- **Karar bekleyen**: `status ∈ {review, critical}`; açık gelir. Satır: durum simgesi (🔒 kritik,
  ? inceleme, 📁 klasör), ad, → hedef (köke göre göreli; central modda tam yol), kategori seçici,
  açıklama alanı (Enter/odak kaybında kaydedilir), onay kutusu, alt satırda sebep · güven · karar
  kaynağı. Kritik satırın onay kutusu yalnızca satırın kendisinden değişir; toplu işlemlere dahil olmaz.
- **Hazır**: kategori başlıklarına göre gruplanmış, kapalı gelir; başlıkta sayı ve üç durumlu onay
  kutusu (`PlanEditor` toplu onay/ret, kritikleri asla kapsamaz). Açılınca satırlar aynı satır
  bileşeniyle görünür.
- **Atlanan**: kapalı, sebebe göre sayılar; açılınca salt okunur satırlar.
- **Arama** ad üzerinde filtreler (tüm bölümlerde).
- **Pencere açılınca**: aynı kök için 24 saatten yeni, uygulanmamış `ready` bir plan varsa (ör. CLI'dan)
  o yüklenir, kullanıcının kararları korunur; yoksa tarama başlar (`inProgress` plan varsa Planner onu
  sürdürür). "Yeniden tara" her zaman yeni plan üretir. Açılışta Ollama sağlığı kontrol edilir; sorun
  varsa tarama yalnızca kurallarla yapılır ve banner gösterilir (CLI ile aynı mantık).
- Klasör satırlarında açıklama alanı gösterilmez (klasör adları yalnızca normalize edilir).
- Her satır düzenlemesi `PlanEditor` ile yapılır ve plan **hemen** `PlanStore`'a yazılır (CLI aynı
  planı görür).
- Alt çubuk: tarama/LLM ilerlemesi (`PlanProgress`), "İptal" (Task iptali; Planner checkpoint'i korur).
- **Detaylı incele (n)**: 2. aşama; n = onaysız inceleme+kritik sayısı; model yüklü değilse buton
  devre dışı ve açıklama gösterir.
- **Uygula (n)**: n = onaylı öğe; 0 ise devre dışı. Onay sayfası: taşınacak sayı, kategori dağılımı,
  elle onaylanmış kritik öğeler ayrı liste, "Uygula" / "Vazgeç". Sonuç sayfası: taşınan/atlanan
  (sebepli)/hatalı, "Geri Al", "Finder'da göster". Uygulanmış plan penceresi salt okunur olur.

### 5.3 Açılış penceresi

Üç büyük düğme (Masaüstü, İndirilenler, Klasör seç… → `NSOpenPanel` / `fileImporter`), altında
"Son işlemler" (en çok 5; tarih, kök, taşınan sayı, durum, "Geri Al"), altta Ollama durum göstergesi
(yeşil: erişilebilir + 1. aşama modeli yüklü; sarı: erişilebilir ama model yok; kırmızı: erişilemiyor)
ve "Ayarlar…" bağlantısı.

### 5.4 Geçmiş penceresi

`RunLog.list` tablosu: tarih, kök, taşınan, durum (aktif / geri alındı). Seçili işlem için
"Geri Al" → sonuç özeti (geri yüklenen, kaldırılan klasör, atlananlar + sebep).

### 5.5 Ayarlar

| Sekme | İçerik |
|---|---|
| Adlandırma | 5 preset radyo düğmesi; her birinin yanında **canlı örnek** (`NamingTemplate` ile, örnek dosya: `download (3).pdf`, Fatura, "Enerjisa Ocak", bugünün tarihi); kategori dili TR/EN |
| Hedef | Klasörün içinde / Merkezi arşiv (klasör seçici); yıl alt klasörü |
| Model | LLM açık/kapalı; sağlayıcı URL; 1./2. aşama model seçicileri (`health().availableModels`); güven eşiği kaydırıcısı; parti boyutu; içerik önizleme; durum göstergesi + "Yenile" |
| Hariç tutma | gizli/uygulama paketleri; son N dakika; glob listesi (ekle/sil); proje işaretleri listesi (ekle/sil) |

Değişiklikler anında `SettingsStore.save`. Var olan planlar kendi `settingsSnapshot`'larını korur;
yeni ayarlar yeni planlarda geçerli olur (ekranda bir satırla belirtilir).

### 5.6 Mimari

```
App/
├── project.yml                     # XcodeGen: TrimlyApp + TrimlyAppTests, TrimlyCore'a yerel paket bağımlılığı
├── TrimlyApp/
│   ├── App/        TrimlyApp, AppDelegate, URLRouter
│   ├── Start/      StartView, StartModel
│   ├── Plan/       PlanWindow, PlanSession, PlanSections, ItemRow, CategoryGroupHeader, ApplySheet, ResultSheet
│   ├── History/    HistoryView, HistoryModel
│   ├── Settings/   SettingsView + sekme view'ları, SettingsModel
│   ├── Shared/     OllamaStatus, StatusBadge, PathFormatting
│   └── Resources/  Assets.xcassets, Info.plist (CFBundleURLTypes: trimly)
└── TrimlyAppTests/                 # Swift Testing: view model'ler (view'lar test edilmez)
```

- View model'ler `@MainActor @Observable final class`; motor çağrıları `async` (Planner `@concurrent`,
  Executor/Undoer §6'da `@concurrent` olur), sonuçlar MainActor'da uygulanır. View'larda iş mantığı yok.
- `PlanSession`: tek bir kök için plan yaşam döngüsü (tara, iptal, satır düzenle, toplu onay,
  2. aşama, uygula, geri al), bölümleri ve sayıları hesaplanmış özellikler olarak sunar.
- Bağımlılıklar enjekte edilir (`DataDirectory`, `LLMProvider`, `now`) — testler geçici dizin ve
  `MockLLMProvider` kullanır.
- Uzun işler `.task` / saklanan `Task` ile; pencere kapanınca iptal edilir.
- Erişilebilirlik: tüm simge düğmelerinde metin etiketi, durum simgelerinde VoiceOver açıklaması.

## 6. Çekirdek değişiklikleri (TrimlyCore)

1. **Veri dizini kilidi**: `DataLock` — `flock(LOCK_EX | LOCK_NB)` ile veri dizinindeki `lock`
   dosyası. `Executor.apply` ve `Undoer.undo` süre boyunca tutar; meşgulse
   `"Başka bir Trimly işlemi sürüyor"` hatası. `Recovery.recoverAll` kilidi alamazsa journal'lara
   dokunmaz (canlı bir apply'ı bozmasın).
2. **Bitmemiş plan düzenlenemez**: `PlanEditor.set` / `bulkApprove` `inProgress` planda
   `PlanError.notReady` (Faz 1 ertelenen minor).
3. **Uygula ve geri al ana thread dışında**: `Executor.apply` ve `Undoer.undo` `@concurrent async`
   olur; CLI ve testler `await` ile çağırır.
4. **Toplu ret ve hazır plan bulma**: `PlanEditor.bulkReject(_:categoryID:) -> Int` (kategori başlığındaki
   onay kutusunu kaldırmak için; ret güvenli olduğu için kritikleri de kapsar) ve
   `PlanStore.latestReady(root:now:) -> Plan?` (24 saatten yeni, `ready` durumda, aynı kök).
5. **Uygulanmış planı önce kontrol**: CLI `apply`, onay sormadan önce plan durumunu kontrol eder
   (Faz 1 ertelenen minor; uygulamadaki onay sayfası da aynı sırayı izler).

## 7. Test ve doğrulama

- Çekirdek: `swift test` (yeni testler: kilit meşgulken apply/undo hata verir, recoverAll kilitliyken
  atlar, inProgress düzenleme reddi, async apply/undo).
- Uygulama: `xcodebuild test -scheme TrimlyApp` — `PlanSession` (bölüm sayıları, kritik satırın toplu
  onaydan hariç kalması, düzenlemenin diske yazılması, iptal sonrası checkpoint, uygula → sonuç →
  geri al), `SettingsModel` (anında kayıt, canlı adlandırma örneği), `URLRouter` (geçerli/geçersiz
  URL'ler), `HistoryModel`.
- Elle doğrulama (gerçek klasörlerde **uygula yok**; yalnızca geçici test klasörleri):
  1. Uygulama kapalıyken `open "trimly://organize?path=<geçici klasör>"` → yalnızca plan penceresi
     açılır, uygulama kendiliğinden kapanmaz; ekran görüntüsü alınır.
  2. Ayarlar penceresi açıkken tüm plan/açılış pencereleri kapatılır → uygulama Ayarlar kapanana kadar
     çalışmaya devam eder, Ayarlar kapanınca sonlanır.
  3. Tarama sürerken plan penceresi kapatılır → görev iptal olur, uygulama sonlanır, `inProgress`
     plan diske yazılmıştır; yeniden açınca kaldığı yerden sürer.

## 8. Kararlarım

- Düzen B (kullanıcı kararı bana bıraktı).
- Açılış penceresi kısayolları + Dock menüsü (Faz 3 yedeği şimdiden hazır olur).
- Satır düzenlemeleri anında diske yazılır (ayrı "Kaydet" yok).
- Pencere açılınca son 24 saatteki uygulanmamış hazır plan yüklenir (CLI'dan başlanan iş uygulamada sürer).
- Uygulanmış plan penceresi salt okunur; yeniden düzenlemek için "Yeniden tara" yeni plan üretir.
- Bundle id `app.trimly.Trimly`; `.xcodeproj` repoya girmez.
- Arayüz metinleri Türkçe.

## 9. Geliştiriciye bırakılanlar

SwiftUI bileşen seçimi (List + DisclosureGroup veya Table + OutlineGroup), görsel ayrıntılar, simgeler
(SF Symbols), uygulama ikonu (geçici SF Symbol tabanlı ikon yeterli), boş durum metinleri.
