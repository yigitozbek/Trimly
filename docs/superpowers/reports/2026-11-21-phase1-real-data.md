# Faz 1 — Gerçek veri ölçümü (2026-11-21)

Ortam: M2 Pro, 16 GB, macOS 27, Ollama 0.40.16. Yalnızca `trimly plan` / `trimly review` çalıştırıldı (salt okunur); gerçek klasörlerde `apply` **çalıştırılmadı**. Dosya adları rapora alınmadı.

## 1. Kural-yalnız plan (`--no-llm`)

| | ~/Downloads | ~/Desktop |
|---|---|---|
| Toplam öğe | 388 | 17 |
| Atlanan | 23 (proje klasörü 12, `.app` 8, sistem 2, gizli 1) | 3 |
| Kuralla kesin | 258 (%66) | 5 |
| Hazır (otomatik onaylı) | 239 | 5 |
| İnceleme | 101 (LLM'siz zayıf kural 79, klasör 22) | 9 (hepsi klasör) |
| Kritik | 25 | 0 |
| Süre (sıcak) | **0.43 sn** (optimizasyon öncesi 1.0 sn) | 0.20 sn |

- İnceleme desenleri: klasör ×22, `.pdf` ×21, `.json` ×16, uzantısız ×8, `.md` ×8, `.zip` ×8, `.jar` ×5, `.csv` ×4.
- Kritik 25: uzantı 19 (`.sql` 7, `.der` 5, `.cer` 3, `.udf` 3, `.pem` 1) + "rapor" anahtar kelimesi 6.
- Hazır olanların dağılımı: fotoğraf 107, görsel 71, video 32, kurulum 12, veri 6.

### Performans düzeltmesi
`sample` profili zamanın çoğunun Spotlight IPC'sinde (`MDItemCopyAttribute`, öğe başına 5 çağrı) geçtiğini gösterdi. Tek `MDItemCopyAttributes` çağrısına geçildi: 388 öğe 1.0 sn → 0.43 sn, istatistikler birebir aynı. Spec hedefi (400 öğe < 1 sn) karşılanıyor.

### Gerçek veriden çıkan kural düzeltmeleri (TDD ile)
- **Güvenlik:** Downloads'ta Android imza anahtarları (`.keystore`, `.jks`) bulundu; kritik değillerdi (adları LLM'e gidebilir, toplu onaya girebilirlerdi). Artık **kritik + Sertifika-Anahtar**.
- `.aab`, `.jnlp` → Kurulum; `.htm` → Kod (`.html` ile aynı).
