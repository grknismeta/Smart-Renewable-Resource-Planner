"""İl adı alias / normalize tablosu (2026-05-19).

DB'de bazı iller kısaltma + ASCII normalize edilmiş şekilde kayıtlı:
  - "K. Maras"        ↔ "Kahramanmaraş"
  - "Afyon"           ↔ "Afyonkarahisar"
  - "Balikesir"       ↔ "Balıkesir"   (sadece ASCII fold)
  - "Çanakkale"       ↔ "Canakkale"    (sadece ASCII fold)

ASCII fold (`_tr_ascii_fold`) sadece Türkçe karakter çevirir (ı→i, ş→s).
Kısaltmalı isim farklılıkları (K. Maras vs Kahramanmaraş, Afyon vs
Afyonkarahisar) için bu **manuel alias** tablosu gerekiyor.

Vault'taki "iller-arası ilçe karışıklığı" issue'u ([[INBOX]]) bu temaya
ait — uzun vade canonical lookup tablosu (GADM tabanlı) gelene kadar
bu pratik fix kullanılıyor.

**Kullanım:**

    from app.services.province_aliases import canonical_match_filter

    # pin.city = "Kahramanmaraş", DB'de "K. Maras" → filter eşleşir
    q.filter(canonical_match_filter(HourlyWeatherData.city_name, pin.city))
"""
from __future__ import annotations

from typing import Sequence

from sqlalchemy import or_


# Bilinen alias'lar — `frontend pin.city` → `DB city_name` map.
# Anahtar canonical (Türkçe doğru), değer DB'deki olası varyasyonlar.
_PROVINCE_ALIASES: dict[str, list[str]] = {
    "Kahramanmaraş": ["K. Maras", "K.Maras", "Kahramanmaras", "K Maras"],
    "Afyonkarahisar": ["Afyon"],
    # Türkçe karakter farklılıkları zaten `_tr_ascii_fold` ile çözülüyor;
    # burada yalnız KISALTMALI veya farklı yazımlar tutulur.
    # Yeni alias'lar bulunca buraya ekle.
}

# ASCII → Türkçe canonical (BIDIRECTIONAL — 2026-05-24).
# `_tr_ascii_fold` sadece Türkçe→ASCII çeviriyor (i→i ambiguity yüzünden geri
# dönüşüm belirsiz). Bu manuel map ASCII varyasyonu için canonical Türkçe
# karşılığını verir — CSV ASCII formatından Türkçe canonical climatology
# satırına eşleşme için zorunlu. 81 il'den özel Türkçe karakter içerenler.
_ASCII_TO_TR: dict[str, str] = {
    "Adiyaman": "Adıyaman",
    "Agri": "Ağrı",
    "Aydin": "Aydın",
    "Balikesir": "Balıkesir",
    "Bartin": "Bartın",
    "Bingol": "Bingöl",
    "Canakkale": "Çanakkale",
    "Cankiri": "Çankırı",
    "Corum": "Çorum",
    "Diyarbakir": "Diyarbakır",
    "Duzce": "Düzce",
    "Elazig": "Elazığ",
    "Eskisehir": "Eskişehir",
    "Gumushane": "Gümüşhane",
    "Igdir": "Iğdır",
    "Istanbul": "İstanbul",
    "Izmir": "İzmir",
    "Karabuk": "Karabük",
    "Kirikkale": "Kırıkkale",
    "Kirklareli": "Kırklareli",
    "Kirsehir": "Kırşehir",
    "Kutahya": "Kütahya",
    "Mugla": "Muğla",
    "Mus": "Muş",
    "Nevsehir": "Nevşehir",
    "Nigde": "Niğde",
    "Sanliurfa": "Şanlıurfa",
    "Sirnak": "Şırnak",
    "Tekirdag": "Tekirdağ",
    "Usak": "Uşak",
    # Kahramanmaraş özel — kısaltmalar manuel
    "Kahramanmaras": "Kahramanmaraş",
}


def to_canonical(name: str) -> str:
    """Herhangi bir formattaki il adını Türkçe canonical'a normalize eder.

    Tüm climatology insert path'leri bu fonksiyondan geçmeli — DB'de tek
    canonical (Türkçe) satır kalsın. Mevcut bozuk veriyi düzeltmek için
    `dedup_climatology.py` script'i ile birlikte kullanılır.
    """
    if not name:
        return name
    # Önce manuel kısaltmalar (Kahramanmaraş, Afyonkarahisar)
    for canonical, variants in _PROVINCE_ALIASES.items():
        if name in variants or name == canonical:
            return canonical
    # Sonra ASCII → Türkçe
    if name in _ASCII_TO_TR:
        return _ASCII_TO_TR[name]
    # Türkçe canonical'sa aynen dön
    return name


def _tr_ascii_fold(s: str) -> str:
    """Türkçe → ASCII fold. climatology_service ile birebir aynı."""
    fold = str.maketrans({
        "İ": "I", "I": "I", "ı": "i", "i": "i",
        "Ğ": "G", "ğ": "g",
        "Ş": "S", "ş": "s",
        "Ç": "C", "ç": "c",
        "Ö": "O", "ö": "o",
        "Ü": "U", "ü": "u",
    })
    return (s or "").translate(fold)


def province_aliases(name: str) -> list[str]:
    """Bir il için olası tüm yazım varyasyonlarını döner.

    Sırayla: orijinal, ASCII fold (Türkçe→ASCII), bidirectional ASCII→Türkçe,
    manuel kısaltma alias'ları. İki yönlü çalışır:
        - "Balıkesir" → ["Balıkesir", "Balikesir"]
        - "Balikesir" → ["Balikesir", "Balıkesir"]
        - "Kahramanmaraş" → ["Kahramanmaraş", "K. Maras", "Kahramanmaras", ...]
    """
    if not name:
        return []
    out: list[str] = []
    out.append(name)
    # Türkçe → ASCII fold
    fold = _tr_ascii_fold(name)
    if fold != name:
        out.append(fold)
    # ASCII → Türkçe (bidirectional)
    if name in _ASCII_TO_TR:
        out.append(_ASCII_TO_TR[name])
    if fold in _ASCII_TO_TR:
        out.append(_ASCII_TO_TR[fold])
    # Manuel kısaltma alias map (Kahramanmaraş, Afyonkarahisar)
    for key in (name, fold):
        if key in _PROVINCE_ALIASES:
            out.extend(_PROVINCE_ALIASES[key])
            out.append(key)  # canonical isim de listede olsun
    # Tekrarları kaldır (sırayı koru)
    seen = set()
    result = []
    for v in out:
        if v not in seen:
            seen.add(v)
            result.append(v)
    return result


def canonical_match_filter(column, name: str):
    """SQLAlchemy OR filter — kolonda il adının tüm varyasyonlarını eşleştir.

    Kullanım:
        q.filter(canonical_match_filter(HourlyWeatherData.city_name, "Kahramanmaraş"))
    """
    variants = province_aliases(name)
    if not variants:
        return None
    return or_(*[column == v for v in variants])
