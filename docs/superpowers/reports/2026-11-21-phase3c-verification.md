# Faz 3c — Elle doğrulama ve gerçek veri ölçümü (2026-11-21)

Yöntem: Debug CLI (`swift build`); geçici klasörlerde `plan` → `trash --yes` → `undo` ve boşaltılmış Çöp senaryosu. Arayüz tıklamaları bu turda yapılamadı (Accessibility / Screen Recording izni yok); aynı akışlar `PlanSessionTrashTests` (2) ve `scripts/smoke.sh` trash senaryosuyla otomatik doğrulandı. Gerçek klasörlerde yalnız `trimly plan --no-llm` (geçici `--data-dir`, kullanıcının ayar kopyası + varsayılan çöp eşikleri); ölçüm planları silindi. Rapor dosya adı içermez.

## Geçici klasör (CLI)

| # | Senaryo | Sonuç |
|---|---|---|
| 1 | Eski `.dmg` (mtime ~40 gün) | ✅ Plan notu `30 günden eski kurulum dosyası`; `trash --yes` → kaynak yok; `undo` → kaynak geri; `trashedRunID` temizlendi. |
| 2 | Özdeş kopya çifti (`fatura.pdf` + `fatura (1).pdf`) | ✅ `(1)` aday (`… ile aynı içerik`); orijinal aday değil; trash + undo OK. |
| 3 | Boş dosya | ✅ Aday `Boş dosya`; trash + undo OK. |
| 4 | Çöp boşaltılmış gibi (`to` silindi) | ✅ Undo `atlanan 1` · `Çöp Kutusu'nda bulunamadı (boşaltılmış olabilir)`. |
| 5 | Smoke (`scripts/smoke.sh`) | ✅ Eski senaryolar + trash; `SMOKE OK`. |

Arayüz (otomatik test / derleme; tıklama yok):
- `trashCandidateAppearsInSection`, `trashAndUndoFromSession` geçti.
- Plan'da **Çöp adayları** bölümü; Ayarlar › **Çöp** sekmesi (5 kural + 2 gün eşiği).
- Geçmiş satırında trash run başlığı / `çöp N`; geri alma etkin.

Doğrulamada bulunup düzeltilen:
- Başarılı trash undo sonrası `trashedRunID` temizlenmiyordu → tekrar çöp / UI adayı kırılıyordu (`fix(core): clear trashedRunID after successful trash undo`).

## Gerçek veri (LLM kapalı, salt okunur)

Kullanıcı ayarı: `targetMode=central`, `scanDepth=3`, `recentMinutes=60`. Çöp anahtarları ayarda yok → motor varsayılanları (`installer=30`, `partial=1`, duplicates/empty/temp açık).

| Klasör | Süre | Öğe | Sınır | Çöp adayı | oldInstaller | stalePartial | duplicate | emptyFile | tempFile |
|---|---|---|---|---|---|---|---|---|---|
| İndirilenler | 1,21 sn | 677 | aşılmadı | 23 | 0 | 0 | 22 | 1 | 0 |
| Masaüstü | 0,32 sn | 105 | aşılmadı | 0 | 0 | 0 | 0 | 0 | 0 |

- İndirilenler'deki adayların çoğu özdeş kopya; kurulum / yarım indirme / geçici bu taramada yok.
- Masaüstü öğe sayısı önceki 3a/3b ölçümlerinden düşük (klasör içeriği değişmiş olabilir); bu turda çöp adayı görülmedi.
- `apply` / `trash` gerçek klasörlerde çalıştırılmadı.

## Otomatik doğrulama

- `swift test`: 226 test / 32 suite geçti.
- `zsh scripts/smoke.sh`: `SMOKE OK`.
- `xcodebuild … -only-testing:TrimlyAppTests/PlanSessionTrashTests`: 2/2 geçti.

## Notlar

- Ruling: Arayüz tıklamalı doğrulama atlandı — osascript Assistive Access ve Computer Use Screen Recording kapalı. Bedeli: Çöp sekmesi / satır düğmelerinin elle tıklanması bu raporda yok; otomatik testler ve CLI karşılıyor.
