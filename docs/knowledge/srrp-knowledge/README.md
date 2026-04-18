# SRRP Knowledge Vault

Smart Renewable Resource Planner projesinin atomik bilgi tabanı.

## Kullanım

### Obsidian ile
1. Obsidian'ı aç.
2. "Open folder as vault" → bu klasörü seç (`docs/knowledge/srrp-knowledge`).
3. [[INDEX]] notunu aç — her şey oradan başlar.

### Obsidian'sız (düz markdown)
- Dosyaları VS Code, sublime, nano gibi herhangi bir editörle aç.
- `[[WikiLink]]` ifadeleri cross-reference'lar — anahtar kelimeyi dosya adıyla ara.
- `INDEX.md` ana harita.

## Yapı

```
srrp-knowledge/
├── INDEX.md                 ← 🏠 Başlangıç noktası
├── README.md                ← Bu dosya
├── _template.md             ← Yeni not şablonu
├── concepts/                ← Domain kavramları
├── viewmodels/              ← State yönetimi
├── widgets/                 ← UI bileşenleri
├── backend/                 ← Python/FastAPI
└── pitfalls/                ← Tuzaklar, kural ihlalleri
```

## Yeni Not Nasıl Yazılır

1. `_template.md`'yi kopyala.
2. Uygun klasöre yerleştir. Dosya adı = not başlığı (CamelCase), örn. `SelectionModes.md`.
3. Frontmatter'ı doldur: `tags`, `updated`, `related`, (kod notu ise) `file`.
4. Wiki linkler kullan: `[[OtherNote]]` — Obsidian otomatik bağlar.
5. [[INDEX]]'e ekle — "yapılacak" listesindeyse işareti kaldır.

## Güncelleme Workflow'u

- **Kod değişti → ilgili notu aynı commit'te güncelle.**
- `updated:` alanını güncel tutmak zorunlu.
- "Son Değişimler" bölümüne 1 satırlık özet ekle.
- Pre-commit hook (`.git/hooks/pre-commit`) kodla birlikte not güncellemediysen uyarı verir.

## Neden Bu Vault Var?

Detaylı açıklama: [[INDEX]] ve [[PlatformConsistency]].

Kısaca:
1. Token tasarrufu — büyük dosyaları baştan okumadan bilgiyi çıkarmak için.
2. AI ajanlara (Claude, Antigravity, vb.) tutarlı rehber.
3. Projeye yeni katılan biri için başlangıç noktası.
4. "Eskiden nasıl yapılırdı?" tarihçesi için.
