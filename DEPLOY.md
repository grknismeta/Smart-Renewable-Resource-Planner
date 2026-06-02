# SRRP — DigitalOcean Deploy Rehberi (2026-06-02)

Sunucu: `164.92.177.205` · Domain: `srrp-app.com` (DNS A kayıtları droplet'e bakıyor)
Mimari: **Caddy** (80/443, otomatik HTTPS + statik frontend + `/api` reverse proxy) →
**backend** (içeride) → **db/redis** (içeride). Hepsi `docker-compose.prod.yml`.

---

## 0) Önkoşullar (TAMAM)
- [x] Domain + DNS A (`@`, `www` → 164.92.177.205)
- [x] Droplet Ubuntu 24.04, Docker + Compose kurulu

---

## 1) Droplet hazırlığı (sunucuda, Web Console / SSH)

```bash
# Flutter web build RAM-yoğun → 4GB droplet'te OOM olmasın diye 2GB swap
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# (Opsiyonel ama önerilir) Güvenlik duvarı: sadece SSH + web
ufw allow 22 && ufw allow 80 && ufw allow 443 && ufw --force enable

# Repo'yu çek (data/vector ve .env gitignore'da — onları aşağıda elle koyacağız)
git clone <REPO_URL> srrp && cd srrp
```

---

## 2) `.env` dosyasını oluştur (sunucuda, repo kökünde)

```bash
cat > .env <<'EOF'
SECRET_KEY=<SECRET_KEY_DEGERI>
POSTGRES_USER=srrp_admin
POSTGRES_PASSWORD=<DB_SIFRE_DEGERI>
POSTGRES_DB=srrp_db
ALLOWED_ORIGINS=https://srrp-app.com,https://www.srrp-app.com
GOOGLE_API_KEY=<GEMINI_API_KEY>
GEMINI_MODEL=gemini-flash-latest
EOF
```
> ⚠️ Gerçek değerleri (SECRET_KEY, DB şifresi, GOOGLE_API_KEY) **repoya YAZMA** —
> bunlar gizli. Değerler ayrıca (chat'te) verildi; `.env` yalnız sunucuda durur
> (.gitignore + .dockerignore ile repoya/Docker image'a girmez).

---

## 3) LOKAL PC'de: veritabanı dump + sınır dosyaları hazırla

### 3a. DB dump (PowerShell, proje kökünde)
```powershell
$env:PGPASSWORD='srrp_secure_2026'
pg_dump -h localhost -U srrp_admin -d srrp_db -Fc -f srrp_db.dump
# pg_dump bulunamazsa tam yol: & "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" ...
```
(Çıktı `srrp_db.dump` — birkaç yüz MB olabilir, weather_data 3.2M satır.)

### 3b. Sınır (il/ilçe) vektör dosyaları (~48MB — gitignore'da, ayrı taşınır)
Taşınacaklar: `backend/data/vector/` altından
`turkey_provinces_osm.geojson`, `turkey_districts_osm.geojson`,
`gadm41_TUR_1.*`, `gadm41_TUR_2.*`

---

## 4) LOKAL PC → Droplet'e transfer (scp)

```powershell
# DB dump
scp srrp_db.dump root@164.92.177.205:/root/srrp/

# Sınır dosyaları (droplet'te dizini oluştur, sonra kopyala)
ssh root@164.92.177.205 "mkdir -p /root/srrp/backend/data/vector"
scp backend/data/vector/turkey_provinces_osm.geojson `
    backend/data/vector/turkey_districts_osm.geojson `
    backend/data/vector/gadm41_TUR_1.* `
    backend/data/vector/gadm41_TUR_2.* `
    root@164.92.177.205:/root/srrp/backend/data/vector/
```

---

## 5) Droplet'te: DB restore + build + başlat

```bash
cd /root/srrp

# 1) Önce SADECE db'yi başlat (boş srrp_db oluşur)
docker compose -f docker-compose.prod.yml up -d db
sleep 12   # healthy olsun

# 2) Dump'ı restore et (container içine pipe)
docker compose -f docker-compose.prod.yml exec -T db \
  pg_restore -U srrp_admin -d srrp_db --clean --if-exists --no-owner < srrp_db.dump
#   (PostGIS uyarıları normal; "errors ignored on restore" görmek olağan)

# 3) Hepsini başlat (frontend build dahil — flutter build ~birkaç dk)
docker compose -f docker-compose.prod.yml up -d --build
```

İlk `up --build`:
- Flutter web build (Caddy image içinde) ~3-6 dk.
- Caddy başlayınca `srrp-app.com` için **otomatik HTTPS sertifikası** alır (~30sn).

---

## 6) Google OAuth — domain ekle (SEN, Google Console)
console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0 Client →
**Authorized JavaScript origins** → ekle: `https://srrp-app.com` (ve istersen `https://www.srrp-app.com`). Kaydet.

---

## 7) Doğrulama
- `https://srrp-app.com` açılmalı (yeşil kilit / HTTPS).
- Giriş/Kayıt, Google ile giriş, harita, ML projeksiyon çalışmalı.
- Loglar: `docker compose -f docker-compose.prod.yml logs -f backend`
- Caddy/sertifika: `docker compose -f docker-compose.prod.yml logs -f caddy`

---

## Sorun giderme
- **Site açılmıyor / sertifika yok:** DNS yayıldı mı? (`dig srrp-app.com` → 164.92.177.205). 80/443 açık mı (ufw).
- **Harita sınırları yok:** `backend/data/vector` dosyaları droplet'te repo'da mı? (adım 4).
- **DB boş/hata:** restore çıktısını kontrol et; `docker compose exec db psql -U srrp_admin -d srrp_db -c "\dt"` ile tabloları gör.
- **Flutter build OOM:** swap açık mı (adım 1)?
- **Google giriş hata:** Authorized origins'e domain eklendi mi (adım 6)?

## Güncelleme (sonraki deploylar)
```bash
cd /root/srrp && git pull
docker compose -f docker-compose.prod.yml up -d --build
```
