# Faz 2 — Elle doğrulama (2026-11-21)

Yöntem: Debug derlemesi, geçici test klasörleri ve geçici veri dizini (`launchctl setenv TRIMLY_DATA_DIR …`, test sonrası `unsetenv`). Ekran kaydı izni olmadığı için ekran görüntüsü yerine System Events erişilebilirlik sorguları kullanıldı (pencere adları, kontroller, menüler). Gerçek klasörlerde Uygula/Geri Al **otomasyonla yapılmadı**.

| # | Senaryo | Sonuç |
|---|---|---|
| 1 | Uygulama kapalıyken `open "trimly://organize?path=…"` | ✅ Yalnızca plan penceresi; uygulama çalışmaya devam ediyor. (İlk denemede açılış penceresi de açılıyordu → açılıştan sonraki 3 sn içindeki link için açılış penceresini kapatan `LaunchState` eklendi; normal açılışta açılış penceresi görünür, uygulama açıkken gelen link açılış penceresini kapatmaz — ikisi de doğrulandı.) |
| 2 | Ayarlar açıkken diğer pencereleri kapat | ✅ Yalnız Ayarlar açıkken uygulama çalışıyor; Ayarlar kapanınca sonlanıyor. |
| 3 | Tarama (gerçek Ollama, 12 dosya, parti 2) sürerken plan penceresini kapat | ✅ Uygulama sonlandı; plan `inProgress`, 2/12 sınıflanmış olarak diskte. Yeniden açınca aynı plan kimliğiyle kaldığı yerden sürdü ve `ready` oldu. |
| 4 | Dock menüsü | ✅ "Masaüstünü Düzenle", "İndirilenleri Düzenle" görünüyor (tıklanmadı). |

Ek gözlemler:
- Ayarlar menü öğesinin kısayolu Türkçe Q klavyede ⌘Ö olarak eşleniyor (`AXMenuItemCmdChar = Ö`); System Events ile gönderilen ⌘, bu yüzden çalışmadı. Uygulama hatası değil.
- Plan penceresi erişilebilirlik ağacı: karar bekleyen satırlarda onay kutusu, durum simgesi, ad, "→ hedef", kategori seçici, ayrıntı satırı ("klasör, elle onay gerekir · güven 0.60 · karar: kural") doğrulandı.
- Kullanıcı test sırasında kendi isteğiyle Masaüstü kısayolu → onaylar → Uygula akışını uçtan uca kullandı (geçici veri dizininde kayıtlı işlem `r-20261121-104530`, yedek: `.superpowers/incident-desktop-run-backup/data`).
- Uygulama günlüğünde plan yüklenirken SwiftUI `List` kaynaklı "reentrant operation in its NSTableView delegate" uyarısı görüldü; görsel bir sorun gözlenmedi (izlenecek).
