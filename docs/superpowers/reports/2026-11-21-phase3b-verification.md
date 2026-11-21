# Faz 3b — Elle doğrulama ve gerçek veri ölçümü (2026-11-21)

Yöntem: Debug CLI (`swift build`); geçici klasörlerde `plan` → `apply` → `undo` ve `xattr` / `NSURL.tagNames` okuma. Arayüz tıklamaları bu turda yapılamadı (Accessibility / Screen Recording izni yok); aynı akışlar `PlanSessionTagTests` (3) ve `scripts/smoke.sh` tagOnly senaryosuyla otomatik doğrulandı. Gerçek klasörlerde yalnız `trimly plan --no-llm` (geçici `--data-dir`, kullanıcının ayar kopyası); ölçüm planları silindi. Rapor dosya adı içermez.

## Geçici klasör (CLI)

| # | Senaryo | Sonuç |
|---|---|---|
| 1 | Taşıma + etiket (`fatura-ocak.pdf`, mevcut etiket `Proje X`) | ✅ Hedefte `Proje X,Fatura`; özet `Taşınan: 1 · Etiketlenen: 1`; plan satırı `＋Fatura` ve `etiket: Proje X`. |
| 2 | Geri Al (taşıma) | ✅ Kaynak geri geldi; etiketler yine `Proje X` (`etiketi geri alınan 1`). |
| 3 | `tagOnly` apply | ✅ Dosya yerinde; etiket `Fatura`; `Taşınan: 0 · Etiketlenen: 1`. |
| 4 | `tagOnly` undo | ✅ Etiket listesi boş. |
| 5 | `tagMappings` (`Vergi` → invoices) + etiketli `belge.pdf` | ✅ Plan: kategori Faturalar, `Etiket: Vergi`, `＋ Fatura etiketi`. |
| 6 | Smoke (`scripts/smoke.sh`) | ✅ Eski senaryolar + tagOnly; `SMOKE OK`. |

Arayüz (otomatik test / derleme; tıklama yok):
- `tagOnlyPlanIsApprovableAndSummarized`, `tagOnlyApplyAndUndoRestoreTags`, `selectAllUsesTagActions` geçti.
- Ayarlar › Hedef'te `tagOnly` ve "kategori etiketi ekle" toggle; Etiketler sekmesi eklendi (`TagsTab`).

## Gerçek veri (derinlik kullanıcının ayarı, LLM kapalı, salt okunur)

Kullanıcı ayarı: `targetMode=central`, `tagMappings` boş, `addCategoryTags` anahtarı yok → varsayılan açık.

| Klasör | Mod | Süre | Öğe | Finder etiketi olan | Etiketle karar | `tagsToAdd` | Onaylı eylem | Sınır |
|---|---|---|---|---|---|---|---|---|
| İndirilenler | central (kullanıcı) | 0,84 sn | 524 | 0 | 0 | 365 | 314 | aşılmadı |
| Masaüstü | central (kullanıcı) | ~2–38 sn* | 1.738 | 0 | 0 | 14 | 5 | aşılmadı |
| İndirilenler | tagOnly (ölçüm) | 0,73 sn | 524 | 0 | 0 | 365 | 314 | aşılmadı |
| Masaüstü | tagOnly (ölçüm) | 1,98 sn | 1.738 | 0 | 0 | 14 | 5 | aşılmadı |

\* İlk Masaüstü taraması ~38 sn sürdü (muhtemelen soğuk önbellek); tekrar ~2 sn.

- Taranan öğelerde Finder etiketi görülmedi; etiket kuralı bu klasörlerde tetiklenmedi.
- `tagsToAdd` sayıları, varsayılan `addCategoryTags` / `tagOnly` ile kategori etiketi eklenecek öğeleri gösterir (kapsanan / atlanan hariç etkin satırlar).
- Merkezi arşiv uyarısı (3a'dan): İndirilenler'de kategori klasörlerindeki öğeler arşive taşınma önerisi olarak kalır; `tagOnly`'ye geçilirse taşınma olmaz, yalnız etiket eklenir.

## Notlar

- Ruling: Arayüz tıklamalı doğrulama atlandı — osascript Assistive Access ve Computer Use Screen Recording kapalı. Bedeli: Etiketler sekmesinin elle tıklanması bu raporda yok; otomatik testler ve CLI mapping senaryosu karşılıyor.
- macOS 14'te etiket yazma `NSURL.setResourceValue(_:forKey: .tagNamesKey)` ile (URLResourceValues setter macOS 26+).
