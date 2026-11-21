# Trimly — UX: çoklu klasör, Finder, Etiketler, önizleme

**Tarih:** 2026-11-21  
**Durum:** Onaylandı (kullanıcı: önerilen paket)

## Sorun

- Sonuç sayfasındaki **Finder'da göster** plan kökünü açıyor; taşınan dosyalar / satır bağlamı yok → “çalışmıyor” hissi.
- Başlangıç yalnızca tek klasör; kullanıcı Masaüstü / İndirilenler / Belgeler’i birlikte veya seçerek düzenlemek istiyor (tüm disk değil).
- İndirilenler’de yeni dosyalar `recentMinutes` ile sessizce atlanınca “hiç düzeltmedi” algısı oluşuyor.
- **Etiketler** ayarı var ama `SettingsLink` ilk sekmeyi açıyor; deep-link yok.
- Satırda / seçimde dosya **önizlemesi** (Quick Look) yok.

## Kararlar

1. **Çoklu klasör seçimi (zorunlu üçlü tarama yok):** Başlangıçta Masaüstü · İndirilenler · Belgeler kutucukları + mevcut “Klasör seç…”. Seçilen her klasör için ayrı plan penceresi açılır (mevcut `WindowGroup` modeli korunur; tek birleşik plan/çok köklü motor yok).
2. **Finder:** Sonuç sayfasında mümkünse taşınan hedefleri (yoksa kökü) seçili gösterir. Plan satırında bağlamsal “Finder'da göster” (kaynak; çöpteyse `trashed` yolu yoksa atlanır).
3. **Etiketler deep-link:** Ayarlar sahnesi seçili sekme ile açılabilir (`SettingsTab.tags` vb.); plandaki etiket notundan / banner’dan Etiketler sekmesine gidiş.
4. **Önizleme:** Seçili satırda Space → sistem Quick Look (`QLPreviewPanel`); desteklenmeyen türlerde sessizce no-op veya kısa uyarı.
5. **“Neden boş?”:** Plan’da atlanan “Son N dakikada…” sayısı belirgin banner; neredeyse tüm etkin öğeler buysa Ayarlar › Hariç tutma kısayolu.

## Dışı

- Ev dizini / tüm disk taraması.
- Tek planda birden fazla kök (çoklu `Plan.root`).
- Toplu çöp / kalıcı silme.
- Finder etiket rengi sütunu (sistem Finder UI).

## Güvenlik

- Gerçek klasörlerde yalnız plan/önizleme; `apply` / `trash` kullanıcı onayıyla.
- Quick Look salt okunur; dosya içeriği LLM’e bu özellik yüzünden gitmez.
