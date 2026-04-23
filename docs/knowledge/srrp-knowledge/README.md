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
├── INBOX.md                 ← 📥 İşlenmemiş sorunlar (hızlı dump)
├── README.md                ← Bu dosya
├── _template.md             ← Yeni kod notu şablonu
├── concepts/                ← Domain kavramları
├── viewmodels/              ← State yönetimi
├── widgets/                 ← UI bileşenleri
├── backend/                 ← Python/FastAPI
├── pitfalls/                ← Tuzaklar, kural ihlalleri
└── issues/                  ← Çözülmüş/aktif sorunlar (post-mortem)
    └── _template.md         ← Yeni issue şablonu
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

## Sorun Bildirme Workflow'u (INBOX → issues/)

**Sen yazarsın:**
1. `INBOX.md`'yi aç (Obsidian'da Ctrl+O → "INBOX").
2. Bugünün tarih başlığı altına `- [ ] sorun` ekle.
3. Varsa ekran görüntüsü, konsol log, tekrar üretim adımları yapıştır.
4. Aciliyet: `[!]` = kritik, `[?]` = belirsiz, `[*]` = sadece not.

**Claude işler (oturum başında):**
1. INBOX'ı okur, açık item'ları listeler.
2. Onay verirsen sırayla çözer.
3. Her çözülen için:
   - `issues/YYYY-MM-DD-slug.md` post-mortem yazar (kök sebep + çözüm + commit).
   - INBOX'ta `[x]` işaretler + `→ [[issues/...]]` linki ekler.
   - İlgili kod notunu günceller (`updated`, "Son Değişimler").
4. Bitince rapor verir.

**Örnek:**
```markdown
## 2026-04-18
- [ ] [!] Android'de ilçe moduna geçince harita beyazlıyor
- [ ] Bulutlar açılmıyor, konsol temiz
```

Sonra:
```markdown
## 2026-04-18
- [x] [!] Android beyaz harita → [[issues/2026-04-18-android-ilce-beyaz]]
- [x] Bulutlar açılmıyor → [[issues/2026-04-18-bulut-katmani-gorunmuyor]]
```

## Neden Bu Vault Var?

Detaylı açıklama: [[INDEX]] ve [[PlatformConsistency]].

Kısaca:
1. Token tasarrufu — büyük dosyaları baştan okumadan bilgiyi çıkarmak için.
2. AI ajanlara (Claude, Antigravity, vb.) tutarlı rehber.
3. Projeye yeni katılan biri için başlangıç noktası.
4. "Eskiden nasıl yapılırdı?" tarihçesi için.
