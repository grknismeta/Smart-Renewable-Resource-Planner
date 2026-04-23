---
tags: [issue, resolved, backend, faz1, analysis]
opened: 2026-04-22
resolved: 2026-04-22
severity: high
platform: backend
related: ["PLAN-2026-04-19-to-23", "INBOX"]
---

# Faz 1 Analysis Service — İlk Canlı Test 3 Bug

## Belirti

Adım 5 sonrası backend çalıştırıldığında:
1. `/analysis/provinces?type=wind` → **500 Internal Server Error**
2. `/analysis/choropleth/wind` → `count: 0, scores: {}` (boş)
3. `/system/status` → `last_status: "running"` sürekli takılı

Haritada kısmi choropleth var (eski endpoint'ten) ama yeni endpoint'ler boş.

## Kök Sebep (3 ayrı bug)

### 1. `score_3m` kolonu DB'de yoktu
Model'de var (`models.py`), migration'da var (`012_add_province_analysis.py`), ama DB zaten `create_all()` ile daha eski model sürümünden yaratılmıştı. `create_all()` mevcut tabloya kolon **eklemez**. Sonuçta her `SELECT` PostgreSQL `UndefinedColumn: column province_analysis.score_3m does not exist` dönüyor.

### 2. SQLAlchemy 2.0.19+ Row tek-harf label çakışması
`_aggregate_window`'da:
```python
.label("w"), .label("s"), .label("t"), .label("n")
```

`r.t` erişimi SQLAlchemy Row'un dahili `.t` method'u ile çakışıyor → `r.t` float yerine tüm Row'u döner. `_weighted(b["t"])` içinde `float(v)` çağrısında **TypeError: float() argument must be ... not 'Row'**.

Uyarı: `The Row.t attribute is deprecated in favor of Row._t; all Row methods and library-level attributes are intended to be underscored to avoid name conflicts. (deprecated since: 2.0.19)`

### 3. Scheduler ilk tetiklemede 2'nin kurbanı → status takıldı
Scheduler startup'ta `recompute_all_provinces` çağırdı, Bug 1/2 ile crash, ama `_mark_run_end` çağrısı öncesinde exception raise edildi → `last_status` "running" kaldı.

## Çözüm

### 1. `ALTER TABLE`
```sql
ALTER TABLE province_analysis ADD COLUMN IF NOT EXISTS score_3m DOUBLE PRECISION;
```
İdempotent, Python one-liner ile raw SQL. Migration'ın DB'ye hiç uygulanmadığı keşfi: ileride `alembic upgrade head` gerekli.

### 2. `_mapping` ile sürüm-güvenli label erişimi
`analysis_service.py` `_aggregate_window`:
- Label'lar uzatıldı: `w → avg_wind`, `s → avg_solar`, `t → avg_temp`, `p_hourly_mean_mm → avg_precip_hourly_mm`, `n → sample_n`.
- Attribute erişimi yerine `r._mapping["avg_temp"]` kullan — Row method çakışmasından bağımsız.

### 3. Scheduler meta reset
```sql
UPDATE scheduler_meta SET last_status='pending', last_error=NULL WHERE last_status='running';
```

## Doğrulama

`recompute_all_provinces()` elle çağrıldı:
```
OK: {'provinces': 81, 'rows_written': 243, 'windows': 4} (sure: 9.0s)
```

Endpoint testleri:
- `/analysis/provinces?type=wind&horizon=6m&limit=5` → Çanakkale 87.35 (top), Edirne 71.67, Tekirdağ 66.55 ✓ fiziksel olarak doğru (Trakya rüzgar koridoru)
- `/analysis/choropleth/wind?horizon=6m` → 81 il, min 0.10 max 87.35 ✓
- `/analysis/choropleth/solar` → 81 il, min 25.05 max 37.41 ✓ (dar aralık, 6m ortalama kış dahil)
- `/analysis/choropleth/hydro` → 81 il, min 43.54 max 99.90 ✓

## Tekrarlamamak İçin

- ⚠️ **Model'e kolon eklendiğinde**: Alembic migration yaz **VE** DB'de uygula. `create_all()`'a güvenme — mevcut tabloya kolon eklemez. Dev/demo için hızlı yol: `ALTER TABLE ADD COLUMN IF NOT EXISTS`.
- ⚠️ **SQLAlchemy 2.0 tek-harf label**: `.label("t")` gibi kısa label'lar Row method'larıyla çakışır (`.t`, `.n`, `.count` vb.). Uzun label ver veya `._mapping["..."]` kullan.
- ⚠️ **Scheduler hata toparlaması**: Job crash ederse status "running" kalabilir — `_run_tracked` zaten try/except içinde `_mark_run_end("fail", ...)` çağırıyor ama yine de izlenmeli. İlk sprint iteration'ında meta reset gerekebilir.

## Dosyalar

- `backend/app/services/analysis_service.py` — label + `_mapping` fix (`_aggregate_window`)
- Raw SQL: `ALTER TABLE province_analysis ADD COLUMN score_3m`, `UPDATE scheduler_meta SET last_status='pending'`

## Bağlantılar

- [[PLAN-2026-04-19-to-23]] — Faz 1 altyapı
- [[INBOX]] — Faz 1 devam ediyor
- [[WeatherRouter]] — HourlyWeatherData konumu

## Tarihçe

- **2026-04-22 00:46**: Recompute başarılı, 81 il × 3 kaynak × 4 pencere = 243 satır 9s'de yazıldı. Wind Top-1 Çanakkale 87.35 — fiziksel beklentiyle tutarlı.
