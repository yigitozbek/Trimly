# UX — Finder, çoklu klasör, Etiketler, önizleme (2026-11-21)

Branch: `ux-finder-preview-multifolders` (3c üzerine).

## Yapılanlar

| İstek | Sonuç |
|---|---|
| Finder'da göster | Taşınan hedefler (yoksa kök); satır bağlam menüsü |
| Etiketler yönlendirme | `SettingsOpener.open(.tags)`; satır etiket / bağlam menüsü |
| Önizleme | Seçim + Space / Önizle / bağlam menüsü → Quick Look |
| Çoklu klasör | Masaüstü · İndirilenler · Belgeler kutucukları + “Seçilenleri aç” (ayrı pencereler) |
| “Hiç düzeltmedi” | `recentMinutes` atlama banner’ı + Hariç tutma kısayolu |

## Test

- App: FinderReveal (4), SettingsTab (2), QuickLook (2), FolderPicker (2), RecentBanner (2) — geçti.
- `swift test` (çekirdek) — geçti (doğrulama anında).

## Elle

Arayüz tıklaması bu turda yapılmadı; otomatik testler + derleme.
