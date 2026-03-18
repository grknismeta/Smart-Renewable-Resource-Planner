"""
generate_turkey_districts_nominatim.py
=======================================
Overpass API yerine Nominatim (OSM geocoding) kullanarak
Turkiye ilce merkezlerinin GERCEK koordinatlarini uretir.

Avantajlari:
  - Overpass gibi buyuk polygon sorgusu yok, basit isim sorgulari
  - Her ilce icin "ilce_adi, il_adi, Turkey" seklinde sorgu → gercek sehir merkezi
  - Admin_centre logic otomatik olarak Nominatim icinde

Kullanim:
  cd backend
  python generate_turkey_districts_nominatim.py

Not: ~975 ilce × 1.2 sn = ~20 dakika surar. Script kesilirse kaldigi yerden devam eder.
"""

import requests
import json
import time
import sys
from pathlib import Path

# Windows encoding duzeltmesi
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
HEADERS = {"User-Agent": "SRRP-TurkeyDistricts/2.0 (smart-renewable-resource-planner)"}

# ── Turkiye'nin 81 ili ve ilceleri ────────────────────────────────────────────
# Kaynak: TurkStat / resmi idari birimler listesi
# Format: (il_adi, [ilce_adi, ...])
TURKEY_DISTRICTS = [
    ("Adana", ["Aladağ","Ceyhan","Çukurova","Feke","İmamoğlu","Karaisalı","Karataş","Kozan","Pozantı","Saimbeyli","Sarıçam","Seyhan","Tufanbeyli","Yumurtalık","Yüreğir"]),
    ("Adıyaman", ["Adıyaman","Besni","Çelikhan","Gerger","Gölbaşı","Kahta","Samsat","Sincik","Tut"]),
    ("Afyonkarahisar", ["Afyonkarahisar","Başmakçı","Bayat","Bolvadin","Çay","Çobanlar","Dazkırı","Dinar","Emirdağ","Evciler","Hocalar","İhsaniye","İscehisar","Kızılören","Sandıklı","Sinanpaşa","Sultandağı","Şuhut"]),
    ("Ağrı", ["Ağrı","Diyadin","Doğubayazıt","Eleşkirt","Hamur","Patnos","Taşlıçay","Tutak"]),
    ("Aksaray", ["Aksaray","Ağaçören","Eskil","Gülağaç","Güzelyurt","Ortaköy","Sarıyahşi","Sultanhanı"]),
    ("Amasya", ["Amasya","Göynücek","Gümüşhacıköy","Hamamözü","Merzifon","Suluova","Taşova"]),
    ("Ankara", ["Akyurt","Altındağ","Ayaş","Bala","Beypazarı","Çamlıdere","Çankaya","Çubuk","Elmadağ","Etimesgut","Evren","Gölbaşı","Güdül","Haymana","Kalecik","Kahramankazan","Keçiören","Kızılcahamam","Mamak","Nallıhan","Polatlı","Pursaklar","Sincan","Şereflikoçhisar","Yenimahalle"]),
    ("Antalya", ["Akseki","Aksu","Alanya","Demre","Döşemealtı","Elmalı","Finike","Gazipaşa","Gündoğmuş","İbradı","Kaş","Kemer","Kepez","Konyaaltı","Korkuteli","Kumluca","Manavgat","Muratpaşa","Serik"]),
    ("Ardahan", ["Ardahan","Çıldır","Damal","Göle","Hanak","Posof"]),
    ("Artvin", ["Ardanuç","Arhavi","Artvin","Borçka","Hopa","Kemalpaşa","Murgul","Şavşat","Yusufeli"]),
    ("Aydın", ["Bozdoğan","Buharkent","Çine","Didim","Efeler","Germencik","İncirliova","Karacasu","Karpuzlu","Koçarlı","Köşk","Kuşadası","Kuyucak","Nazilli","Söke","Sultanhisar","Yenipazar"]),
    ("Balıkesir", ["Altıeylül","Ayvalık","Balya","Bandırma","Bigadiç","Burhaniye","Dursunbey","Edremit","Erdek","Gömeç","Gönen","Havran","İvrindi","Karesi","Kepsut","Manyas","Marmara","Savaştepe","Sındırgı","Susurluk"]),
    ("Bartın", ["Arit","Bartın","Kurucaşile","Ulus"]),
    ("Batman", ["Batman","Beşiri","Gercüş","Hasankeyf","Kozluk","Sason"]),
    ("Bayburt", ["Aydıntepe","Bayburt","Demirözü"]),
    ("Bilecik", ["Bozüyük","Bilecik","Gölpazarı","İnhisar","Osmaneli","Pazaryeri","Söğüt","Yenipazar"]),
    ("Bingöl", ["Adaklı","Bingöl","Genç","Karlıova","Kiğı","Merkez","Solhan","Yayladere","Yedisu"]),
    ("Bitlis", ["Adilcevaz","Ahlat","Bitlis","Güroymak","Hizan","Mutki","Tatvan"]),
    ("Bolu", ["Bolu","Dörtdivan","Gerede","Göynük","Kıbrıscık","Mengen","Mudurnu","Seben","Yeniçağa"]),
    ("Burdur", ["Ağlasun","Altınyayla","Bucak","Burdur","Çavdır","Çeltikçi","Gölhisar","Karamanlı","Kemer","Merkez","Tefenni","Yeşilova"]),
    ("Bursa", ["Büyükorhan","Gemlik","Gürsu","Harmancık","İnegöl","İznik","Karacabey","Keles","Kestel","Mudanya","Mustafakemalpaşa","Nilüfer","Orhaneli","Orhangazi","Osmangazi","Yenişehir","Yıldırım"]),
    ("Çanakkale", ["Ayvacık","Bayramiç","Biga","Bozcaada","Çan","Çanakkale","Eceabat","Ezine","Gelibolu","Gökçeada","Lapseki","Merkez","Yenice"]),
    ("Çankırı", ["Atkaracalar","Bayramören","Çankırı","Eldivan","Ilgaz","Kızılırmak","Korgun","Kurşunlu","Orta","Şabanözü","Yapraklı"]),
    ("Çorum", ["Alaca","Bayat","Boğazkale","Dodurga","İskilip","Kargı","Laçin","Mecitözü","Merkez","Oğuzlar","Ortaköy","Osmancık","Sungurlu","Uğurludağ"]),
    ("Denizli", ["Acıpayam","Babadağ","Baklan","Bekilli","Beyağaç","Bozkurt","Buldan","Çal","Çameli","Çardak","Çivril","Güney","Honaz","Kale","Merkezefendi","Pamukkale","Sarayköy","Serinhisar","Tavas"]),
    ("Diyarbakır", ["Bağlar","Bismil","Çermik","Çınar","Çüngüş","Dicle","Eğil","Ergani","Hani","Hazro","Kayapınar","Kocaköy","Kulp","Lice","Silvan","Sur","Yenişehir"]),
    ("Düzce", ["Akçakoca","Cumayeri","Çilimli","Düzce","Gölyaka","Gümüşova","Kaynaşlı","Yığılca"]),
    ("Edirne", ["Edirne","Enez","Havsa","İpsala","Keşan","Lalapaşa","Meriç","Süloğlu","Uzunköprü"]),
    ("Elazığ", ["Ağın","Alacakaya","Arıcak","Baskil","Elazığ","Karakoçan","Keban","Kovancılar","Maden","Palu","Sivrice"]),
    ("Erzincan", ["Çayırlı","Erzincan","İliç","Kemah","Kemaliye","Otlukbeli","Refahiye","Tercan","Üzümlü"]),
    ("Erzurum", ["Aşkale","Aziziye","Çat","Hınıs","Horasan","İspir","Karayazı","Köprüköy","Narman","Oltu","Olur","Palandöken","Pasinler","Pazaryolu","Şenkaya","Tekman","Tortum","Uzundere","Yakutiye"]),
    ("Eskişehir", ["Alpu","Beylikova","Çifteler","Günyüzü","Han","İnönü","Mahmudiye","Mihalgazi","Mihalıççık","Odunpazarı","Sarıcakaya","Seyitgazi","Sivrihisar","Tepebaşı"]),
    ("Gaziantep", ["Araban","İslahiye","Karkamış","Nurdağı","Oğuzeli","Şahinbey","Şehitkamil","Nizip","Yavuzeli"]),
    ("Giresun", ["Alucra","Bulancak","Çamoluk","Çanakçı","Dereli","Doğankent","Espiye","Eynesil","Giresun","Görele","Güce","Keşap","Merkez","Piraziz","Şebinkarahisar","Tirebolu","Yağlıdere"]),
    ("Gümüşhane", ["Gümüşhane","Kelkit","Köse","Kürtün","Merkez","Şiran","Torul"]),
    ("Hakkari", ["Çukurca","Hakkari","Şemdinli","Yüksekova"]),
    ("Hatay", ["Altınözü","Antakya","Arsuz","Belen","Defne","Dörtyol","Erzin","Hassa","İskenderun","Kırıkhan","Kumlu","Payas","Reyhanlı","Samandağ","Yayladağı"]),
    ("Iğdır", ["Aralık","Iğdır","Karakoyunlu","Tuzluca"]),
    ("Isparta", ["Aksu","Atabey","Eğirdir","Gelendost","Gönen","Isparta","Keçiborlu","Merkez","Senirkent","Sütçüler","Şarkikaraağaç","Uluborlu","Yalvaç","Yenişarbademli"]),
    ("İstanbul", ["Adalar","Arnavutköy","Ataşehir","Avcılar","Bağcılar","Bahçelievler","Bakırköy","Başakşehir","Bayrampaşa","Beşiktaş","Beykoz","Beylikdüzü","Beyoğlu","Büyükçekmece","Çatalca","Çekmeköy","Esenler","Esenyurt","Eyüpsultan","Fatih","Gaziosmanpaşa","Güngören","Kadıköy","Kağıthane","Kartal","Küçükçekmece","Maltepe","Pendik","Sancaktepe","Sarıyer","Silivri","Sultanbeyli","Sultangazi","Şile","Şişli","Tuzla","Ümraniye","Üsküdar","Zeytinburnu"]),
    ("İzmir", ["Aliağa","Balçova","Bayındır","Bayraklı","Bergama","Beydağ","Bornova","Buca","Çeşme","Çiğli","Dikili","Foça","Gaziemir","Güzelbahçe","Karabağlar","Karaburun","Karşıyaka","Kemalpaşa","Kınık","Kiraz","Konak","Menderes","Menemen","Narlıdere","Ödemiş","Seferihisar","Selçuk","Tire","Torbalı","Urla"]),
    ("Kahramanmaraş", ["Afşin","Andırın","Çağlayancerit","Dulkadiroğlu","Ekinözü","Elbistan","Göksun","Nurhak","Onikişubat","Pazarcık","Türkoğlu"]),
    ("Karabük", ["Eflani","Eskipazar","Karabük","Ovacık","Safranbolu","Yenice"]),
    ("Karaman", ["Ayrancı","Başyayla","Ermenek","Karaman","Kazımkarabekir","Merkez","Sarıveliler"]),
    ("Kars", ["Akyaka","Arpaçay","Digor","Kağızman","Kars","Sarıkamış","Selim","Susuz"]),
    ("Kastamonu", ["Abana","Ağlı","Araç","Azdavay","Bozkurt","Cide","Çatalzeytin","Daday","Devrekani","Doğanyurt","Hanönü","İhsangazi","İnebolu","Kastamonu","Küre","Pınarbaşı","Seydiler","Şenpazar","Taşköprü","Tosya"]),
    ("Kayseri", ["Akkışla","Bünyan","Develi","Felahiye","Hacılar","İncesu","Kocasinan","Melikgazi","Özvatan","Pınarbaşı","Sarıoğlan","Sarız","Talas","Tomarza","Yahyalı","Yeşilhisar"]),
    ("Kırıkkale", ["Bahşılı","Balışeyh","Çelebi","Delice","Karakeçili","Keskin","Kırıkkale","Sulakyurt","Yahşihan"]),
    ("Kırklareli", ["Babaeski","Demirköy","Kırklareli","Kofçaz","Lüleburgaz","Pehlivanköy","Pınarhisar","Vize"]),
    ("Kırşehir", ["Akçakent","Akpınar","Boztepe","Çiçekdağı","Kaman","Kırşehir","Mucur"]),
    ("Kilis", ["Elbeyli","Kilis","Musabeyli","Polateli"]),
    ("Kocaeli", ["Başiskele","Çayırova","Darıca","Derince","Dilovası","Gebze","Gölcük","İzmit","Kandıra","Karamürsel","Kartepe","Körfez"]),
    ("Konya", ["Ahırlı","Akören","Akşehir","Altınekin","Beyşehir","Bozkır","Cihanbeyli","Çeltik","Çumra","Derbent","Derebucak","Doğanhisar","Emirgazi","Ereğli","Güneysinir","Hadim","Halkapınar","Hüyük","Ilgın","Kadınhanı","Karapınar","Karatay","Kulu","Meram","Sarayönü","Selçuklu","Seydişehir","Taşkent","Tuzlukçu","Yalıhüyük","Yunak"]),
    ("Kütahya", ["Altıntaş","Aslanapa","Çavdarhisar","Domaniç","Dumlupınar","Emet","Gediz","Hisarcık","Kütahya","Merkez","Pazarlar","Simav","Şaphane","Tavşanlı"]),
    ("Malatya", ["Akçadağ","Arapgir","Arguvan","Battalgazi","Darende","Doğanşehir","Doğanyol","Hekimhan","Kale","Kuluncak","Merkez","Pütürge","Yazıhan","Yeşilyurt"]),
    ("Manisa", ["Ahmetli","Akhisar","Alaşehir","Demirci","Gölmarmara","Gördes","Kırkağaç","Köprübaşı","Kula","Merkez","Salihli","Sarıgöl","Saruhanlı","Selendi","Soma","Şehzadeler","Turgutlu","Yunusemre"]),
    ("Mardin", ["Artuklu","Dargeçit","Derik","Kızıltepe","Mazıdağı","Midyat","Nusaybin","Ömerli","Savur","Yeşilli"]),
    ("Mersin", ["Akdeniz","Anamur","Aydıncık","Bozyazı","Çamlıyayla","Erdemli","Gülnar","Mezitli","Mut","Silifke","Tarsus","Toroslar","Yenişehir"]),
    ("Muğla", ["Bodrum","Dalaman","Datça","Fethiye","Kavaklıdere","Köyceğiz","Marmaris","Menteşe","Milas","Ortaca","Seydikemer","Ula","Yatağan"]),
    ("Muş", ["Bulanık","Hasköy","Korkut","Malazgirt","Merkez","Muş","Varto"]),
    ("Nevşehir", ["Acıgöl","Avanos","Derinkuyu","Gülşehir","Hacıbektaş","Kozaklı","Merkez","Nevşehir","Ürgüp"]),
    ("Niğde", ["Altunhisar","Bor","Çamardı","Çiftlik","Merkez","Niğde","Ulukışla"]),
    ("Ordu", ["Akkuş","Altınordu","Aybastı","Çamaş","Çatalpınar","Çaybaşı","Fatsa","Gölköy","Gülyalı","Gürgentepe","İkizce","Kabadüz","Kabataş","Korgan","Kumru","Mesudiye","Perşembe","Ulubey","Ünye"]),
    ("Osmaniye", ["Bahçe","Düziçi","Hasanbeyli","Kadirli","Merkez","Osmaniye","Sumbas","Toprakkale"]),
    ("Rize", ["Ardeşen","Çamlıhemşin","Çayeli","Derepazarı","Fındıklı","Güneysu","Hemşin","İkizdere","İyidere","Kalkandere","Merkez","Pazar","Rize"]),
    ("Sakarya", ["Adapazarı","Akyazı","Arifiye","Erenler","Ferizli","Geyve","Hendek","Karapürçek","Karasu","Kaynarca","Kocaali","Mithatpaşa","Pamukova","Sapanca","Serdivan","Söğütlü","Taraklı"]),
    ("Samsun", ["19 Mayıs","Alaçam","Asarcık","Atakum","Ayvacık","Bafra","Canik","Çarşamba","Havza","İlkadım","Kavak","Ladik","Merkez","Ondokuzmayıs","Salıpazarı","Tekkeköy","Terme","Vezirköprü","Yakakent"]),
    ("Siirt", ["Baykan","Eruh","Kurtalan","Merkez","Pervari","Şirvan","Tillo"]),
    ("Sinop", ["Ayancık","Boyabat","Dikmen","Durağan","Erfelek","Gerze","İmranlı","Merkez","Saraydüzü","Türkeli"]),
    ("Sivas", ["Akıncılar","Altınyayla","Divriği","Doğanşar","Gemerek","Gölova","Hafik","İmranlı","Kangal","Koyulhisar","Merkez","Sivas","Suşehri","Şarkışla","Ulaş","Yıldızeli","Zara"]),
    ("Şanlıurfa", ["Akçakale","Birecik","Bozova","Ceylanpınar","Eyyübiye","Halfeti","Haliliye","Harran","Hilvan","Karaköprü","Merkez","Siverek","Suruç","Viranşehir"]),
    ("Şırnak", ["Beytüşşebap","Cizre","Güçlükonak","İdil","Merkez","Silopi","Uludere"]),
    ("Tekirdağ", ["Çerkezköy","Çorlu","Ergene","Hayrabolu","Kapaklı","Malkara","Marmaraereğlisi","Muratlı","Saray","Süleymanpaşa","Şarköy"]),
    ("Tokat", ["Almus","Artova","Başçiftlik","Erbaa","Merkez","Niksar","Pazar","Reşadiye","Tokat","Turhal","Yeşilyurt","Zile"]),
    ("Trabzon", ["Akçaabat","Araklı","Arsin","Beşikdüzü","Çarşıbaşı","Çaykara","Dernekpazarı","Düzköy","Hayrat","Köprübaşı","Maçka","Merkez","Of","Ortahisar","Sürmene","Şalpazarı","Tonya","Vakfıkebir","Yomra"]),
    ("Tunceli", ["Çemişgezek","Hozat","Mazgirt","Merkez","Nazımiye","Ovacık","Pertek","Pülümür"]),
    ("Uşak", ["Banaz","Eşme","Karahallı","Merkez","Sivaslı","Ulubey"]),
    ("Van", ["Bahçesaray","Başkale","Çatak","Çaldıran","Edremit","Erciş","Gevaş","Gürpınar","İpekyolu","Merkez","Muradiye","Özalp","Saray","Tuşba"]),
    ("Yalova", ["Altınova","Armutlu","Çiftlikköy","Çınarcık","Merkez","Termal"]),
    ("Yozgat", ["Akdağmadeni","Aydıncık","Boğazlıyan","Çandır","Çayıralan","Çekerek","Kadışehri","Merkez","Saraykent","Sarıkaya","Şefaatli","Sorgun","Yenifakılı","Yerköy","Yozgat"]),
    ("Zonguldak", ["Alaplı","Çaycuma","Devrek","Gökçebey","Kilimli","Kozlu","Merkez","Ereğli"]),
]


def nominatim_search(district, province):
    """Bir ilce icin Nominatim'den koordinat cek."""
    params = {
        "q": f"{district}, {province}, Turkey",
        "format": "json",
        "limit": 1,
        "addressdetails": 1,
        "accept-language": "tr",
        "countrycodes": "tr",
    }
    try:
        r = requests.get(NOMINATIM_URL, params=params, headers=HEADERS, timeout=10)
        r.raise_for_status()
        results = r.json()
        if results:
            return float(results[0]["lat"]), float(results[0]["lon"])
    except Exception:
        pass
    return None, None


def main():
    print("=" * 65)
    print("Turkiye Ilce Koordinat Ureteci — Nominatim (OSM Geocoding)")
    print("=" * 65)

    # Ilerleme kaydi — kesinti durumunda kaldigi yerden devam
    progress_file = Path(__file__).parent / "nominatim_progress.json"
    if progress_file.exists():
        with open(progress_file, "r", encoding="utf-8") as f:
            done = json.load(f)
        print(f"  Onceki ilerleme bulundu: {len(done)} ilce hazir. Devam ediliyor...")
    else:
        done = {}

    total_districts = sum(len(d) for _, d in TURKEY_DISTRICTS)
    cities = []
    new_count = 0
    error_count = 0

    for province, districts in TURKEY_DISTRICTS:
        for district in districts:
            key = f"{district}|{province}"

            if key in done:
                # Onceki oturumdan al
                entry = done[key]
                cities.append(entry)
                continue

            # Nominatim sorgusu
            lat, lon = nominatim_search(district, province)

            if lat is None:
                # Fallback: sadece il adi ile dene
                lat, lon = nominatim_search(province, "Turkey")
                print(f"  [FALLBACK] {district} ({province}): il merkezi kullanildi")
                error_count += 1

            is_center = district.lower() == province.lower()
            entry = {
                "name": district,
                "province": province,
                "district": None if is_center else district,
                "lat": round(lat, 4) if lat else 0,
                "lon": round(lon, 4) if lon else 0,
            }

            done[key] = entry
            cities.append(entry)
            new_count += 1

            # Her 10 ilcede bir kaydet (kesinti koruması)
            if new_count % 10 == 0:
                with open(progress_file, "w", encoding="utf-8") as f:
                    json.dump(done, f, ensure_ascii=False)
                pct = len(cities) / total_districts * 100
                print(f"  [{len(cities):4d}/{total_districts}] {pct:.0f}% | Son: {district} ({province})")

            # OSM kullanim politikasi: 1 istek/saniye
            time.sleep(1.1)

    # Province + isme gore sirala
    cities.sort(key=lambda c: (c["province"], c["name"]))

    print(f"\n  Toplam: {len(cities)} ilce")
    print(f"  Hata/Fallback: {error_count}")

    # JSON kaydet
    json_out = Path(__file__).parent / "turkey_districts.json"
    with open(json_out, "w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)
    print(f"  JSON: {json_out}")

    # constants.py guncelle
    py_out = Path(__file__).parent / "app" / "core" / "constants.py"
    _write_constants(py_out, cities)
    print(f"  constants.py: {py_out}")

    # Ilerleme dosyasini temizle
    if progress_file.exists():
        progress_file.unlink()

    print(f"\nTamamlandi! Sonraki adim: python distribute.py --computers 4")
    print("=" * 65)


def _write_constants(path, cities):
    lines = [
        '"""\n',
        'Turkiye il ve ilce merkezleri\n',
        'Nominatim (OSM) ile uretildi — gercek sehir merkezi koordinatlari\n',
        f'Toplam: {len(cities)} konum\n',
        '"""\n\n',
        'TURKEY_CITIES = [\n',
    ]
    current_province = None
    for c in cities:
        if c["province"] != current_province:
            current_province = c["province"]
            lines.append(f'\n    # {current_province.upper()}\n')
        d = f'"{c["district"]}"' if c["district"] else "None"
        lines.append(
            f'    {{"name": "{c["name"]}", "province": "{c["province"]}", '
            f'"district": {d}, "lat": {c["lat"]}, "lon": {c["lon"]}}},\n'
        )
    lines.append(']\n')
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    main()
