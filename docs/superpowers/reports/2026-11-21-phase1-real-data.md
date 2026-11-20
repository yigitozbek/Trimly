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

## 2. LLM'li plan (1. aşama, `qwen3:4b`) — ~/Downloads

| | Değer |
|---|---|
| LLM'e giden | 107 öğe (zayıf kural 79 + klasör 22 + zayıf+kritik 6) |
| Toplam süre | 340 sn (öğe başına ~3.2 sn; ilk parti model yüklemesiyle daha yavaş) |
| LLM hatası | 0 (şema `format` her yanıtta geçerli JSON üretti) |
| Sonuç | Hazır 308 · İnceleme 32 (klasör 22, düşük güven 10) · Kritik 25 |
| Güven dağılımı | ≥0.9: 46 · 0.75–0.9: 42 · 0.5–0.75: 18 · <0.5: 1 |
| Bellek | `qwen3:4b` 3.2 GB, %100 GPU; sistem boş belleği ~%27–30 |

İnceleme kuyruğu LLM ile 101 → 32'ye indi.

Zayıf uzantılarda LLM kararları: `.pdf` → Belgeler 20 / Resmi-Evrak 2 / Sözleşmeler 2; `.json` → Veri 8 / Kod 4 / **Sertifika 3** / Kurulum 1; `.zip` → Arşiv 5 / Kurulum 3; `.md` → Belgeler 8; `.jar` → Kurulum 5; `.csv` → Tablolar 4.

### LLM kalite bulguları
- **Şema sapması doğrulandı:** model `reason`'ı 160 karakter sınırının çok üstünde yazıyor (Ollama `maxLength`'i uygulamıyor → kodda kesiliyor) ve `suggested_name`'e uzantı/tarih ekliyor.
- **Düzeltildi:** 8/107 açıklamada model, adda olmayan bir tarihi `_20261028` biçiminde eklemişti; sanitizer'ın `\b` deseni alt çizgide kaçırıyordu. Rakam sınırı + geçerli ay/gün kontrolüne geçildi (sipariş numaraları korunuyor), saat eki (`_0148`) de temizleniyor.
- Tuhaf ama zararsız kararlar: `.log` → Kurulum (2), uzantısız 3 dosya → Ekran-Görüntüleri.

## 3. 2. aşama (`ministral-3:14b`, `trimly review`)

| | Değer |
|---|---|
| Aday | 57 (inceleme 32 + kritik 25) |
| Süre | 345 sn (öğe başına ~6 sn) |
| Sonuç | 8 öğe hazıra yükseldi; inceleme 24 kaldı (klasör 22, düşük güven 2) |
| **Kritik bariyeri** | 25 kritik öğenin **hiçbiri** onaylanmadı ✅; içerikleri gönderilmedi |
| Bellek | `qwen3:4b` önce boşaltıldı ✅; `ministral-3:14b` 8.7 GB, %100 GPU; **sistem boş belleği %8–11'e düştü, swap kullanımı ~6.6 GB → ~11 GB** |

16 GB'de 2. aşama çalışırken diğer uygulamalar swap'a itiliyor. Model GPU'ya sığıyor ve iş bitiyor, ama makine yavaşlıyor.

## 4. Öneriler (kullanıcı kararı)

1. ✅ **Uygulandı (final review I5):** **LLM'in hassas bulduğu öğeler kritik sayılsın.** LLM, kurallarla yakalanmayan 7 öğeyi Sertifika-Anahtar (5, çoğu `.json` — servis hesabı anahtarı olabilir) veya Resmi-Evrak (2) olarak sınıflandırdı ve bunlar **otomatik onaylandı**. Artık LLM bir öğeyi `certificates` / `health` / `officialDocs` kategorisine koyarsa öğe kritik oluyor; ayrıca önizlemede anahtar materyali (`-----BEGIN`, `PRIVATE KEY`, `"private_key"` …) görülürse içerik **gönderilmiyor** ve öğe kritik oluyor.
2. **2. aşama modeli:** 16 GB'de swap baskısı nedeniyle `stage2Model` için `gemma3:4b` (3.3 GB) veya `llama3.1` (4.9 GB) denenebilir; ya da ministral korunup 2. aşama yalnızca bilgisayar boştayken çalıştırılır.
3. **Çıktı uzunluğu:** Ollama'ya `num_predict` (~200 token) sınırı verilirse öğe başı süre düşer (çıktı üretimi sürenin çoğu); kesilmiş JSON riski için önce ölçülmeli.
4. Final review sonrası eklendi: `.p8`, `id_rsa`/`id_ed25519`, bileşik `.sql.gz` vb. kritik; `.mobileprovision` artık doğru tanınıyor. Hâlâ eklenmedi: `.ppk`, `.log`, `.ips`.

## 5. Gerçek veride uygulanmadı

Planlar `~/Library/Application Support/Trimly/plans/` altında duruyor. `trimly apply` **kullanıcı onayı olmadan çalıştırılmadı.**

⚠️ `2026-11-21T01-49-02_Downloads` planı final review düzeltmelerinden **önce** üretildi: içinde artık kritik sayılacak 7 otomatik onaylı öğe var. **Bu planı uygulamayın**; `trimly plan ~/Downloads` ile yeniden plan alın.
