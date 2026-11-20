# Trimly

Yerel AI destekli, güvenli macOS dosya/klasör düzenleyici (Swift). Tasarım: `docs/superpowers/specs/2026-11-21-trimly-design.md`. Aktif plan: `docs/superpowers/plans/2026-11-21-trimly-phase1-core-cli.md`.

## Swift skill'leri (zorunlu)

`.claude/skills/` altındaki skill'leri Swift kodu yazarken, test yazarken ve review yaparken kullan:

- `swift-concurrency-pro` — async/await, actor, Sendable, cancellation
- `swift-testing-pro` — tüm testler Swift Testing ile
- `swiftui-pro` — SwiftUI uygulaması (Faz 2) ve genel Swift hijyeni

Kaynak ve sürümler: `.claude/skills/SOURCES.md`.

## Komutlar

- Derleme: `swift build`
- Test: `swift test` (tek suite: `swift test --filter NormalizerTests`)
- CLI smoke: `zsh scripts/smoke.sh`

## Güvenlik kuralları

- Kullanıcı dosyası asla silinmez/üzerine yazılmaz; taşıma yalnızca journal'lı `Executor` üzerinden.
- Testler gerçek `~/Desktop` / `~/Downloads`'a dokunmaz. Gerçek veride yalnızca `trimly plan` (salt okunur); `apply` kullanıcı açık onayı olmadan çalıştırılmaz.
- Kritik dosyaların içeriği LLM'e gitmez; kritik öğeyi hiçbir otomatik adım onaylayamaz.
