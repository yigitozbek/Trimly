# Faz 3a — Elle doğrulama ve gerçek veri ölçümü (2026-11-21)

Yöntem: Debug derlemesi; arayüz için geçici klasör + geçici veri dizini (`launchctl setenv TRIMLY_DATA_DIR …`, sonra `unsetenv`), System Events erişilebilirlik sorguları ve tıklamaları. Gerçek klasörlerde yalnız `trimly plan --no-llm` çalıştırıldı (salt okunur); planlar geçici veri dizinine, kullanıcının gerçek ayarlarının kopyasıyla yazıldı. Rapor dosya adı içermez.

## Arayüz (geçici klasör: üst seviye dosya, karışık `Rastgele/` (pdf+jpg+dmg), `Tatil/` (5 jpg + kimlik.pdf), Trimly adıyla `Faturalar/` dosyası; "boş klasörleri kaldır" açık)

| # | Senaryo | Sonuç |
|---|---|---|
| 1 | İlk yükleme | ✅ Üst seviye grubu (dosya + `Tatil` "Bütün tut", "İçinde 6 öğe · 1 kritik dosya; yalnızca tek tek onaylanabilir"), ardından `Rastgele` başlığı ("Karışık klasör…", Dağıt seçili) ve altında `Rastgele/a.pdf`. `Faturalar` içindeki dosya "Zaten düzenli". Karar bekleyen 3 (başlık sayılmıyor). |
| 2 | `Rastgele` → Bütün tut | ✅ Grup başlığı kayboldu; `Rastgele` üst seviyede satır oldu ("→ Diger/Rastgele", "İçinde 3 öğe"); çocukları hazır bölümünden çıktı (Onaylı 2 → 0). |
| 3 | Tekrar Dağıt | ✅ Grup geri geldi, varsayılan onaylar geri yüklendi (Onaylı 2). |
| 4 | "Tümünü seç" | ✅ Görünen iki dosya onaylandı; kritik dosya taşıyan `Tatil` seçilmedi. Diskteki plan aynı. |
| 5 | Uygula (4) | ✅ 4 dosya kategorilere taşındı; boşalan `Rastgele/` kaldırıldı; `Tatil/` ve `Faturalar/` değişmedi. |
| 6 | Sonuç sayfasında Geri Al | ✅ Ağaç birebir eski hali: `Rastgele/` yeniden oluşturuldu, dosyalar döndü, oluşturulan kategori klasörleri kaldırıldı ("Geri alındı: 4 öğe, 3 klasör kaldırıldı, 0 atlandı"). |

Doğrulamada bulunup düzeltilenler (testli):
- "Detaylı incele (N)" karışık klasörleri de sayıyordu; stage 2 onları incelemiyor → sayı düzeltildi (`stage2CountSkipsMixedFolders`).
- Onay sayfası "Hiçbir dosya silinmez" diyordu; "boş klasörleri kaldır" açıkken metin "Boşalan klasörler kaldırılır; Geri Al onları yeniden oluşturur." oldu (`applySummaryTellsWhenEmptiedFoldersAreRemoved`).

Gözlem (Faz 2'den, düzeltilmedi): "Tümünü seç" düğmesinin erişilebilirlik başlığı boş (yalnız yardım metni var); onay sayfası düğmeleri de başlıksız görünüyor.

## Gerçek veri (derinlik 3, LLM kapalı, salt okunur)

| Klasör | Süre | Öğe (derinlik 0/1/2) | Etkin / kapsanan | Klasör: karışık / bütün tut / sabit | Sınır |
|---|---|---|---|---|---|
| İndirilenler | 0,6–1,1 sn | 524 (41/365/118) | 406 / 118 | 0 / 22 / 18 | aşılmadı |
| Masaüstü | ~1,9 sn | 1.737 (9/16/1.712) | 25 / 1.712 | 0 / 9 / 6 | aşılmadı |

- Kategori klasörlerinin içi (İndirilenler 365 öğe, Masaüstü 16): Trimly adlı dosyaların tamamı tanındı (ad değişmiyor, karar: kural, LLM gerekmiyor).
- Kullanıcının ayarlarında **yıl alt klasörü açık**, eski düzenlemeler yıl klasörsüz yapılmış: yerinde modda bu öğelerin tamamına yıl klasörüne taşıma öneriliyor (İndirilenler: 343 dosya + 22 klasör; Masaüstü: 5 + 9). Kullanıcının gerçek modu **merkezi arşiv**: aynı öğeler arşive göç olarak öneriliyor; dosyalar varsayılan onaylı (İndirilenler'de 314 onaylı, 29 kritik onaysız), klasörler elle onay bekliyor. Bu spec §5.3.6'nın davranışı ("hedef merkezi arşive dönerse … öneriler kendiliğinden çıkar"); kullanıcıya ilk açılışta büyük bir göç planı göreceği söylenmeli.
- Atlananlar: proje klasörleri (package.json ×12, pyproject.toml ×1), uygulama paketleri ×8, sistem/gizli dosyalar.
