"""
Turkiye il ve ilce merkezleri
Kaynak: GADM v4.1 (isimler) + Nominatim OSM (koordinatlar)
Konum kodu: {plaka:02d}{ilce_sirasi:03d}  (örn. 34000=İstanbul merkezi, 55003=Samsun/Atakum)
Eksik büyükşehir ilçeleri eklendi: Efeler(Aydın), Altıeylül+Karesi(Balıkesir),
  Merkezefendi+Pamukkale(Denizli), Artuklu(Mardin), Menteşe(Muğla),
  Süleymanpaşa(Tekirdağ), Altınordu(Ordu), Şehzadeler+Yunusemre(Manisa),
  Atakum+Canik+İlkadım(Samsun), Kilimli+Kozlu(Zonguldak)
"""

from typing import Optional, Dict, Any, List

TURKEY_CITIES = [

    # ADANA
    {"name": "Adana", "province": "Adana", "district": None, "lat": 37.0, "lon": 35.3213},
    {"name": "Aladağ", "province": "Adana", "district": "Aladağ", "lat": 37.5452, "lon": 35.3944},
    {"name": "Ceyhan", "province": "Adana", "district": "Ceyhan", "lat": 37.0289, "lon": 35.8124},
    {"name": "Feke", "province": "Adana", "district": "Feke", "lat": 37.8148, "lon": 35.9117},
    {"name": "Karaisali", "province": "Adana", "district": "Karaisali", "lat": 37.2572, "lon": 35.0586},
    {"name": "Karataş", "province": "Adana", "district": "Karataş", "lat": 36.5646, "lon": 35.3841},
    {"name": "Kozan", "province": "Adana", "district": "Kozan", "lat": 37.4478, "lon": 35.8166},
    {"name": "Pozantı", "province": "Adana", "district": "Pozantı", "lat": 37.4229, "lon": 34.8732},
    {"name": "Saimbeyli", "province": "Adana", "district": "Saimbeyli", "lat": 37.9846, "lon": 36.0888},
    {"name": "Seyhan", "province": "Adana", "district": "Seyhan", "lat": 37.1024, "lon": 35.3061},
    {"name": "Tufanbeyli", "province": "Adana", "district": "Tufanbeyli", "lat": 38.2603, "lon": 36.2221},
    {"name": "Yumurtalık", "province": "Adana", "district": "Yumurtalık", "lat": 36.7676, "lon": 35.7916},
    {"name": "Yüreğir", "province": "Adana", "district": "Yüreğir", "lat": 36.9895, "lon": 35.3409},
    {"name": "İmamoğlu", "province": "Adana", "district": "İmamoğlu", "lat": 37.2577, "lon": 35.6613},
    {"name": "Çukurova", "province": "Adana", "district": "Çukurova", "lat": 37.0023, "lon": 35.3451},
    {"name": "Sarıçam", "province": "Adana", "district": "Sarıçam", "lat": 37.0704, "lon": 35.4015},

    # ADIYAMAN
    {"name": "Besni", "province": "Adiyaman", "district": "Besni", "lat": 37.6911, "lon": 37.8623},
    {"name": "Gerger", "province": "Adiyaman", "district": "Gerger", "lat": 38.0293, "lon": 39.0333},
    {"name": "Gölbaşı", "province": "Adiyaman", "district": "Gölbaşı", "lat": 37.7844, "lon": 37.6396},
    {"name": "Kahta", "province": "Adiyaman", "district": "Kahta", "lat": 37.7861, "lon": 38.6217},
    {"name": "Adiyaman", "province": "Adiyaman", "district": None, "lat": 37.7637, "lon": 38.2763},
    {"name": "Samsat", "province": "Adiyaman", "district": "Samsat", "lat": 37.5785, "lon": 38.4809},
    {"name": "Sincik", "province": "Adiyaman", "district": "Sincik", "lat": 38.0291, "lon": 38.6194},
    {"name": "Tut", "province": "Adiyaman", "district": "Tut", "lat": 37.7944, "lon": 37.9149},
    {"name": "Çelikhan", "province": "Adiyaman", "district": "Çelikhan", "lat": 38.0333, "lon": 38.2424},

    # AFYON
    {"name": "Bayat", "province": "Afyon", "district": "Bayat", "lat": 38.9844, "lon": 30.9256},
    {"name": "Başmakçı", "province": "Afyon", "district": "Başmakçı", "lat": 37.8974, "lon": 30.0098},
    {"name": "Bolvadin", "province": "Afyon", "district": "Bolvadin", "lat": 38.7116, "lon": 31.0455},
    {"name": "Dazkırı", "province": "Afyon", "district": "Dazkırı", "lat": 37.9021, "lon": 29.8624},
    {"name": "Dinar", "province": "Afyon", "district": "Dinar", "lat": 38.0656, "lon": 30.1562},
    {"name": "Emirdağ", "province": "Afyon", "district": "Emirdağ", "lat": 39.0195, "lon": 31.1503},
    {"name": "Evciler", "province": "Afyon", "district": "Evciler", "lat": 38.0271, "lon": 29.9214},
    {"name": "Hocalar", "province": "Afyon", "district": "Hocalar", "lat": 38.5808, "lon": 29.9669},
    {"name": "Kızılören", "province": "Afyon", "district": "Kızılören", "lat": 38.2578, "lon": 30.1492},
    {"name": "Afyon", "province": "Afyon", "district": None, "lat": 38.757, "lon": 30.5387},
    {"name": "Sandıklı", "province": "Afyon", "district": "Sandıklı", "lat": 38.4648, "lon": 30.2725},
    {"name": "Sincanlı", "province": "Afyon", "district": "Sincanlı", "lat": 38.7452, "lon": 30.2452},
    {"name": "Sultandağı", "province": "Afyon", "district": "Sultandağı", "lat": 38.5479, "lon": 31.2682},
    {"name": "Çay", "province": "Afyon", "district": "Çay", "lat": 38.6283, "lon": 31.0355},
    {"name": "Çobanlar", "province": "Afyon", "district": "Çobanlar", "lat": 38.6882, "lon": 30.7389},
    {"name": "İhsaniye", "province": "Afyon", "district": "İhsaniye", "lat": 39.0135, "lon": 30.4032},
    {"name": "İscehisar", "province": "Afyon", "district": "İscehisar", "lat": 38.8621, "lon": 30.751},
    {"name": "Şuhut", "province": "Afyon", "district": "Şuhut", "lat": 38.534, "lon": 30.5461},

    # AGRI
    {"name": "Diyadin", "province": "Agri", "district": "Diyadin", "lat": 39.5398, "lon": 43.6712},
    {"name": "Doğubeyazıt", "province": "Agri", "district": "Doğubeyazıt", "lat": 39.5483, "lon": 44.0794},
    {"name": "Eleşkirt", "province": "Agri", "district": "Eleşkirt", "lat": 39.7984, "lon": 42.6755},
    {"name": "Hamur", "province": "Agri", "district": "Hamur", "lat": 39.6093, "lon": 42.9882},
    {"name": "Agri", "province": "Agri", "district": None, "lat": 39.7215, "lon": 43.0505},
    {"name": "Patnos", "province": "Agri", "district": "Patnos", "lat": 39.2334, "lon": 42.8612},
    {"name": "Taşlıçay", "province": "Agri", "district": "Taşlıçay", "lat": 39.6333, "lon": 43.3777},
    {"name": "Tutak", "province": "Agri", "district": "Tutak", "lat": 39.5394, "lon": 42.7728},

    # AKSARAY
    {"name": "Ağaçören", "province": "Aksaray", "district": "Ağaçören", "lat": 38.869, "lon": 33.9156},
    {"name": "Eskil", "province": "Aksaray", "district": "Eskil", "lat": 38.4017, "lon": 33.4128},
    {"name": "Gülağaç", "province": "Aksaray", "district": "Gülağaç", "lat": 38.3941, "lon": 34.3461},
    {"name": "Güzelyurt", "province": "Aksaray", "district": "Güzelyurt", "lat": 38.2779, "lon": 34.3714},
    {"name": "Aksaray", "province": "Aksaray", "district": None, "lat": 38.3682, "lon": 34.037},
    {"name": "Ortaköy", "province": "Aksaray", "district": "Ortaköy", "lat": 38.7366, "lon": 34.0412},
    {"name": "Sarıyahşi", "province": "Aksaray", "district": "Sarıyahşi", "lat": 38.9849, "lon": 33.8455},
    {"name": "Sultanhanı", "province": "Aksaray", "district": "Sultanhanı", "lat": 38.2076, "lon": 33.6218},

    # AMASYA
    {"name": "Göynücek", "province": "Amasya", "district": "Göynücek", "lat": 40.3971, "lon": 35.5237},
    {"name": "Gümüşhacıköy", "province": "Amasya", "district": "Gümüşhacıköy", "lat": 40.8736, "lon": 35.2159},
    {"name": "Hamamözü", "province": "Amasya", "district": "Hamamözü", "lat": 40.7832, "lon": 35.0242},
    {"name": "Amasya", "province": "Amasya", "district": None, "lat": 40.6499, "lon": 35.8353},
    {"name": "Merzifon", "province": "Amasya", "district": "Merzifon", "lat": 40.8721, "lon": 35.4635},
    {"name": "Suluova", "province": "Amasya", "district": "Suluova", "lat": 40.8364, "lon": 35.6456},
    {"name": "Taşova", "province": "Amasya", "district": "Taşova", "lat": 40.7603, "lon": 36.322},

    # ANKARA
    {"name": "Ankara", "province": "Ankara", "district": None, "lat": 39.9334, "lon": 32.8597},
    {"name": "Akyurt", "province": "Ankara", "district": "Akyurt", "lat": 40.1308, "lon": 33.0871},
    {"name": "Altındağ", "province": "Ankara", "district": "Altındağ", "lat": 39.9524, "lon": 32.8662},
    {"name": "Ayaş", "province": "Ankara", "district": "Ayaş", "lat": 40.0151, "lon": 32.3324},
    {"name": "Bala", "province": "Ankara", "district": "Bala", "lat": 39.5534, "lon": 33.1238},
    {"name": "Beypazarı", "province": "Ankara", "district": "Beypazarı", "lat": 40.1656, "lon": 31.9205},
    {"name": "Elmadağ", "province": "Ankara", "district": "Elmadağ", "lat": 39.9173, "lon": 33.2344},
    {"name": "Etimesgut", "province": "Ankara", "district": "Etimesgut", "lat": 39.9496, "lon": 32.6618},
    {"name": "Evren", "province": "Ankara", "district": "Evren", "lat": 39.0221, "lon": 33.8079},
    {"name": "Gölbaşı", "province": "Ankara", "district": "Gölbaşı", "lat": 39.7925, "lon": 32.8067},
    {"name": "Güdül", "province": "Ankara", "district": "Güdül", "lat": 40.2105, "lon": 32.2432},
    {"name": "Haymana", "province": "Ankara", "district": "Haymana", "lat": 39.4341, "lon": 32.4988},
    {"name": "Kalecik", "province": "Ankara", "district": "Kalecik", "lat": 40.0764, "lon": 33.445},
    {"name": "Kazan", "province": "Ankara", "district": "Kazan", "lat": 40.2054, "lon": 32.6813},
    {"name": "Keçiören", "province": "Ankara", "district": "Keçiören", "lat": 39.9777, "lon": 32.867},
    {"name": "Kızılcahamam", "province": "Ankara", "district": "Kızılcahamam", "lat": 40.4701, "lon": 32.6529},
    {"name": "Mamak", "province": "Ankara", "district": "Mamak", "lat": 39.9314, "lon": 32.9116},
    {"name": "Nallıhan", "province": "Ankara", "district": "Nallıhan", "lat": 40.1888, "lon": 31.3503},
    {"name": "Polatlı", "province": "Ankara", "district": "Polatlı", "lat": 39.5857, "lon": 32.1417},
    {"name": "Sincan", "province": "Ankara", "district": "Sincan", "lat": 39.964, "lon": 32.5856},
    {"name": "Pursaklar", "province": "Ankara", "district": "Pursaklar", "lat": 40.0363, "lon": 32.8962, "code": "06025"},
    {"name": "Şereflikoçhisar", "province": "Ankara", "district": "Şereflikoçhisar", "lat": 38.9427, "lon": 33.5441, "code": "06026"},
    {"name": "Yenimahalle", "province": "Ankara", "district": "Yenimahalle", "lat": 39.9661, "lon": 32.8088},
    {"name": "Çamlıdere", "province": "Ankara", "district": "Çamlıdere", "lat": 40.4915, "lon": 32.4758},
    {"name": "Çankaya", "province": "Ankara", "district": "Çankaya", "lat": 39.8853, "lon": 32.8555},
    {"name": "Çubuk", "province": "Ankara", "district": "Çubuk", "lat": 40.2389, "lon": 33.0289},
    {"name": "Şultan Koçhisar", "province": "Ankara", "district": "Şultan Koçhisar", "lat": 38.9381, "lon": 33.547},

    # ANTALYA
    {"name": "Akseki", "province": "Antalya", "district": "Akseki", "lat": 37.0456, "lon": 31.7897},
    {"name": "Aksu", "province": "Antalya", "district": "Aksu", "lat": 37.0563, "lon": 30.8838, "code": "07019"},
    {"name": "Alanya", "province": "Antalya", "district": "Alanya", "lat": 36.8866, "lon": 30.703},
    {"name": "Elmalı", "province": "Antalya", "district": "Elmalı", "lat": 36.7384, "lon": 29.9184},
    {"name": "Finike", "province": "Antalya", "district": "Finike", "lat": 36.3046, "lon": 30.1445},
    {"name": "Gazipaşa", "province": "Antalya", "district": "Gazipaşa", "lat": 36.2683, "lon": 32.3175},
    {"name": "Gündoğmuş", "province": "Antalya", "district": "Gündoğmuş", "lat": 36.8143, "lon": 31.9983},
    {"name": "Kale", "province": "Antalya", "district": "Kale", "lat": 36.2446, "lon": 29.9876},
    {"name": "Kaş", "province": "Antalya", "district": "Kaş", "lat": 36.1994, "lon": 29.6413},
    {"name": "Kemer", "province": "Antalya", "district": "Kemer", "lat": 36.6014, "lon": 30.5639},
    {"name": "Korkuteli", "province": "Antalya", "district": "Korkuteli", "lat": 37.0667, "lon": 30.197},
    {"name": "Kumluca", "province": "Antalya", "district": "Kumluca", "lat": 36.3669, "lon": 30.2858},
    {"name": "Manavgat", "province": "Antalya", "district": "Manavgat", "lat": 36.787, "lon": 31.4407},
    {"name": "Antalya", "province": "Antalya", "district": None, "lat": 36.8969, "lon": 30.7133},
    {"name": "Serik", "province": "Antalya", "district": "Serik", "lat": 36.9169, "lon": 31.1047},
    {"name": "İbradi", "province": "Antalya", "district": "İbradi", "lat": 37.0969, "lon": 31.5969},
    {"name": "Muratpaşa", "province": "Antalya", "district": "Muratpaşa", "lat": 36.8872, "lon": 30.7039},
    {"name": "Konyaaltı", "province": "Antalya", "district": "Konyaaltı", "lat": 36.8691, "lon": 30.6352},
    {"name": "Kepez", "province": "Antalya", "district": "Kepez", "lat": 36.9334, "lon": 30.7167},
    {"name": "Döşemealtı", "province": "Antalya", "district": "Döşemealtı", "lat": 37.0447, "lon": 30.5996},

    # ARDAHAN
    {"name": "Damal", "province": "Ardahan", "district": "Damal", "lat": 41.3423, "lon": 42.841},
    {"name": "Göle", "province": "Ardahan", "district": "Göle", "lat": 40.7931, "lon": 42.6078},
    {"name": "Hanak", "province": "Ardahan", "district": "Hanak", "lat": 41.2368, "lon": 42.8449},
    {"name": "Ardahan", "province": "Ardahan", "district": None, "lat": 41.1103, "lon": 42.7022},
    {"name": "Posof", "province": "Ardahan", "district": "Posof", "lat": 41.5084, "lon": 42.728},
    {"name": "Çıldır", "province": "Ardahan", "district": "Çıldır", "lat": 41.1266, "lon": 43.1346},

    # ARTVIN
    {"name": "Ardanuç", "province": "Artvin", "district": "Ardanuç", "lat": 41.0914, "lon": 42.1549},
    {"name": "Arhavi", "province": "Artvin", "district": "Arhavi", "lat": 41.3521, "lon": 41.3094},
    {"name": "Borçka", "province": "Artvin", "district": "Borçka", "lat": 41.3602, "lon": 41.6747},
    {"name": "Hopa", "province": "Artvin", "district": "Hopa", "lat": 41.3854, "lon": 41.4632},
    {"name": "Artvin", "province": "Artvin", "district": None, "lat": 41.1828, "lon": 41.8183},
    {"name": "Murgul", "province": "Artvin", "district": "Murgul", "lat": 41.2797, "lon": 41.5641},
    {"name": "Yusufeli", "province": "Artvin", "district": "Yusufeli", "lat": 40.8108, "lon": 41.5271},
    {"name": "Şavşat", "province": "Artvin", "district": "Şavşat", "lat": 41.2525, "lon": 42.3569},
    {"name": "Kemalpaşa", "province": "Artvin", "district": "Kemalpaşa", "lat": 41.4862, "lon": 41.5342},

    # AYDIN
    {"name": "Bozdoğan", "province": "Aydin", "district": "Bozdoğan", "lat": 37.6739, "lon": 28.3132},
    {"name": "Buharkent", "province": "Aydin", "district": "Buharkent", "lat": 37.9527, "lon": 28.7385},
    {"name": "Didim", "province": "Aydin", "district": "Didim", "lat": 37.3697, "lon": 27.2685},
    {"name": "Efeler", "province": "Aydin", "district": "Efeler", "lat": 37.8444, "lon": 27.8458},
    {"name": "Germencik", "province": "Aydin", "district": "Germencik", "lat": 37.8733, "lon": 27.5951},
    {"name": "Karacasu", "province": "Aydin", "district": "Karacasu", "lat": 37.7307, "lon": 28.6063},
    {"name": "Karpuzlu", "province": "Aydin", "district": "Karpuzlu", "lat": 37.559, "lon": 27.8361},
    {"name": "Koçarlı", "province": "Aydin", "district": "Koçarlı", "lat": 37.7622, "lon": 27.7073},
    {"name": "Kuyucak", "province": "Aydin", "district": "Kuyucak", "lat": 37.9097, "lon": 28.4595},
    {"name": "Kuşadası", "province": "Aydin", "district": "Kuşadası", "lat": 37.8632, "lon": 27.2669},
    {"name": "Köşk", "province": "Aydin", "district": "Köşk", "lat": 37.8517, "lon": 28.0515},
    {"name": "Aydin", "province": "Aydin", "district": None, "lat": 37.8444, "lon": 27.8458},
    {"name": "Nazilli", "province": "Aydin", "district": "Nazilli", "lat": 37.9141, "lon": 28.3271},
    {"name": "Sultanhisar", "province": "Aydin", "district": "Sultanhisar", "lat": 37.8873, "lon": 28.1557},
    {"name": "Söke", "province": "Aydin", "district": "Söke", "lat": 37.752, "lon": 27.4056},
    {"name": "Yenipazar", "province": "Aydin", "district": "Yenipazar", "lat": 37.8233, "lon": 28.1957},
    {"name": "Çine", "province": "Aydin", "district": "Çine", "lat": 37.6125, "lon": 28.0623},
    {"name": "İncirliova", "province": "Aydin", "district": "İncirliova", "lat": 37.8538, "lon": 27.725},

    # BALIKESIR
    {"name": "Altıeylül", "province": "Balikesir", "district": "Altıeylül", "lat": 39.6667, "lon": 27.8826},
    {"name": "Ayvalık", "province": "Balikesir", "district": "Ayvalık", "lat": 39.3181, "lon": 26.6917},
    {"name": "Balya", "province": "Balikesir", "district": "Balya", "lat": 39.7499, "lon": 27.5797},
    {"name": "Bandırma", "province": "Balikesir", "district": "Bandırma", "lat": 40.3555, "lon": 27.9698},
    {"name": "Bigadiç", "province": "Balikesir", "district": "Bigadiç", "lat": 39.3913, "lon": 28.132},
    {"name": "Burhaniye", "province": "Balikesir", "district": "Burhaniye", "lat": 39.503, "lon": 26.9807},
    {"name": "Dursunbey", "province": "Balikesir", "district": "Dursunbey", "lat": 39.5473, "lon": 28.653},
    {"name": "Edremit", "province": "Balikesir", "district": "Edremit", "lat": 39.5938, "lon": 27.0157},
    {"name": "Erdek", "province": "Balikesir", "district": "Erdek", "lat": 40.3974, "lon": 27.791},
    {"name": "Gömeç", "province": "Balikesir", "district": "Gömeç", "lat": 39.3901, "lon": 26.8412},
    {"name": "Gönen", "province": "Balikesir", "district": "Gönen", "lat": 40.1044, "lon": 27.6564},
    {"name": "Havran", "province": "Balikesir", "district": "Havran", "lat": 39.5576, "lon": 27.1003},
    {"name": "Karesi", "province": "Balikesir", "district": "Karesi", "lat": 39.6222, "lon": 27.8826},
    {"name": "Kepsut", "province": "Balikesir", "district": "Kepsut", "lat": 39.6899, "lon": 28.1529},
    {"name": "Manyas", "province": "Balikesir", "district": "Manyas", "lat": 40.0477, "lon": 27.968},
    {"name": "Marmara", "province": "Balikesir", "district": "Marmara", "lat": 40.6216, "lon": 27.6294},
    {"name": "Balikesir", "province": "Balikesir", "district": None, "lat": 39.6484, "lon": 27.8826},
    {"name": "Savaştepe", "province": "Balikesir", "district": "Savaştepe", "lat": 39.3856, "lon": 27.656},
    {"name": "Susurluk", "province": "Balikesir", "district": "Susurluk", "lat": 39.9184, "lon": 28.1532},
    {"name": "Sındırgı", "province": "Balikesir", "district": "Sındırgı", "lat": 39.2387, "lon": 28.1749},
    {"name": "İvrindi", "province": "Balikesir", "district": "İvrindi", "lat": 39.582, "lon": 27.4853},

    # BARTIN
    {"name": "Amasra", "province": "Bartın", "district": "Amasra", "lat": 41.7489, "lon": 32.3867},
    {"name": "Kurucaşile", "province": "Bartın", "district": "Kurucaşile", "lat": 41.8439, "lon": 32.7208},
    {"name": "Bartın", "province": "Bartın", "district": None, "lat": 41.6344, "lon": 32.3375},
    {"name": "Ulus", "province": "Bartın", "district": "Ulus", "lat": 41.5836, "lon": 32.6397},

    # BATMAN
    {"name": "Beşiri", "province": "Batman", "district": "Beşiri", "lat": 37.9162, "lon": 41.2928},
    {"name": "Gercüş", "province": "Batman", "district": "Gercüş", "lat": 37.5683, "lon": 41.3852},
    {"name": "Hasankeyf", "province": "Batman", "district": "Hasankeyf", "lat": 37.7305, "lon": 41.4161},
    {"name": "Kozluk", "province": "Batman", "district": "Kozluk", "lat": 38.1933, "lon": 41.4886},
    {"name": "Batman", "province": "Batman", "district": None, "lat": 37.8812, "lon": 41.1351},
    {"name": "Sason", "province": "Batman", "district": "Sason", "lat": 38.3339, "lon": 41.4202},

    # BAYBURT
    {"name": "Aydıntepe", "province": "Bayburt", "district": "Aydıntepe", "lat": 40.3888, "lon": 40.1494},
    {"name": "Demirözü", "province": "Bayburt", "district": "Demirözü", "lat": 40.163, "lon": 39.8913},
    {"name": "Bayburt", "province": "Bayburt", "district": None, "lat": 40.2552, "lon": 40.2249},

    # BILECIK
    {"name": "Bozüyük", "province": "Bilecik", "district": "Bozüyük", "lat": 39.9043, "lon": 30.0373},
    {"name": "Gölpazarı", "province": "Bilecik", "district": "Gölpazarı", "lat": 40.2839, "lon": 30.3165},
    {"name": "Bilecik", "province": "Bilecik", "district": None, "lat": 40.1497, "lon": 29.9796},
    {"name": "Osmaneli", "province": "Bilecik", "district": "Osmaneli", "lat": 40.3643, "lon": 30.0274},
    {"name": "Pazaryeri", "province": "Bilecik", "district": "Pazaryeri", "lat": 39.9954, "lon": 29.9031},
    {"name": "Söğüt", "province": "Bilecik", "district": "Söğüt", "lat": 40.0156, "lon": 30.1814},
    {"name": "Yenipazar", "province": "Bilecik", "district": "Yenipazar", "lat": 40.1767, "lon": 30.5191},
    {"name": "İnhisar", "province": "Bilecik", "district": "İnhisar", "lat": 40.0503, "lon": 30.3848},

    # BINGÖL
    {"name": "Adaklı", "province": "Bingöl", "district": "Adaklı", "lat": 39.2285, "lon": 40.4827},
    {"name": "Genç", "province": "Bingöl", "district": "Genç", "lat": 38.7518, "lon": 40.5576},
    {"name": "Karlıova", "province": "Bingöl", "district": "Karlıova", "lat": 39.2946, "lon": 41.0102},
    {"name": "Kiğı", "province": "Bingöl", "district": "Kiğı", "lat": 39.3104, "lon": 40.3496},
    {"name": "Bingöl", "province": "Bingöl", "district": None, "lat": 38.8846, "lon": 40.4985},
    {"name": "Solhan", "province": "Bingöl", "district": "Solhan", "lat": 38.9659, "lon": 41.0518},
    {"name": "Yayladere", "province": "Bingöl", "district": "Yayladere", "lat": 39.2275, "lon": 40.0686},
    {"name": "Yedisu", "province": "Bingöl", "district": "Yedisu", "lat": 39.434, "lon": 40.5451},

    # BITLIS
    {"name": "Adilcevaz", "province": "Bitlis", "district": "Adilcevaz", "lat": 38.8043, "lon": 42.7346},
    {"name": "Ahlat", "province": "Bitlis", "district": "Ahlat", "lat": 38.7547, "lon": 42.4833},
    {"name": "Güroymak", "province": "Bitlis", "district": "Güroymak", "lat": 38.5742, "lon": 42.0253},
    {"name": "Hizan", "province": "Bitlis", "district": "Hizan", "lat": 38.225, "lon": 42.4263},
    {"name": "Bitlis", "province": "Bitlis", "district": None, "lat": 38.4014, "lon": 42.1079},
    {"name": "Mutki", "province": "Bitlis", "district": "Mutki", "lat": 38.409, "lon": 41.9219},
    {"name": "Tatvan", "province": "Bitlis", "district": "Tatvan", "lat": 38.4932, "lon": 42.2878},

    # BOLU
    {"name": "Dörtdivan", "province": "Bolu", "district": "Dörtdivan", "lat": 40.7206, "lon": 32.0626},
    {"name": "Gerede", "province": "Bolu", "district": "Gerede", "lat": 40.7988, "lon": 32.2009},
    {"name": "Göynük", "province": "Bolu", "district": "Göynük", "lat": 40.3983, "lon": 30.7866},
    {"name": "Kıbrıscık", "province": "Bolu", "district": "Kıbrıscık", "lat": 40.4088, "lon": 31.8487},
    {"name": "Mengen", "province": "Bolu", "district": "Mengen", "lat": 40.9397, "lon": 32.0748},
    {"name": "Bolu", "province": "Bolu", "district": None, "lat": 40.736, "lon": 31.606},
    {"name": "Mudurnu", "province": "Bolu", "district": "Mudurnu", "lat": 40.4657, "lon": 31.2112},
    {"name": "Seben", "province": "Bolu", "district": "Seben", "lat": 40.4085, "lon": 31.5713},
    {"name": "Yeniçağa", "province": "Bolu", "district": "Yeniçağa", "lat": 40.7704, "lon": 32.0336},

    # BURDUR
    {"name": "Altınyayla", "province": "Burdur", "district": "Altınyayla", "lat": 36.9962, "lon": 29.5468},
    {"name": "Ağlasun", "province": "Burdur", "district": "Ağlasun", "lat": 37.6497, "lon": 30.5332},
    {"name": "Bucak", "province": "Burdur", "district": "Bucak", "lat": 37.4567, "lon": 30.5855},
    {"name": "Gölhisar", "province": "Burdur", "district": "Gölhisar", "lat": 37.1511, "lon": 29.5107},
    {"name": "Karamanlı", "province": "Burdur", "district": "Karamanlı", "lat": 37.3709, "lon": 29.8226},
    {"name": "Kemer", "province": "Burdur", "district": "Kemer", "lat": 37.3539, "lon": 30.0611},
    {"name": "Burdur", "province": "Burdur", "district": None, "lat": 37.7203, "lon": 30.2892},
    {"name": "Tefenni", "province": "Burdur", "district": "Tefenni", "lat": 37.3132, "lon": 29.776},
    {"name": "Yeşilova", "province": "Burdur", "district": "Yeşilova", "lat": 37.5064, "lon": 29.7552},
    {"name": "Çavdır", "province": "Burdur", "district": "Çavdır", "lat": 37.155, "lon": 29.69},
    {"name": "Çeltikçi", "province": "Burdur", "district": "Çeltikçi", "lat": 37.5338, "lon": 30.4826},

    # BURSA
    {"name": "Bursa", "province": "Bursa", "district": None, "lat": 40.1828, "lon": 29.0665},
    {"name": "Büyükorhan", "province": "Bursa", "district": "Büyükorhan", "lat": 39.7709, "lon": 28.8854},
    {"name": "Gemlik", "province": "Bursa", "district": "Gemlik", "lat": 40.4302, "lon": 29.1571},
    {"name": "Gürsu", "province": "Bursa", "district": "Gürsu", "lat": 40.2176, "lon": 29.1936},
    {"name": "Harmancık", "province": "Bursa", "district": "Harmancık", "lat": 39.6772, "lon": 29.1538},
    {"name": "Karacabey", "province": "Bursa", "district": "Karacabey", "lat": 40.216, "lon": 28.3591},
    {"name": "Keles", "province": "Bursa", "district": "Keles", "lat": 39.9129, "lon": 29.2342},
    {"name": "Kestel", "province": "Bursa", "district": "Kestel", "lat": 40.2008, "lon": 29.2129},
    {"name": "Mudanya", "province": "Bursa", "district": "Mudanya", "lat": 40.3753, "lon": 28.8838},
    {"name": "Mustafakemalpaşa", "province": "Bursa", "district": "Mustafakemalpaşa", "lat": 40.0347, "lon": 28.3954, "code": "16018"},
    {"name": "Mustafa Kemalpaşa", "province": "Bursa", "district": "Mustafa Kemalpaşa", "lat": 40.0765, "lon": 29.5097},
    {"name": "Nilüfer", "province": "Bursa", "district": "Nilüfer", "lat": 40.217, "lon": 28.9848},
    {"name": "Orhaneli", "province": "Bursa", "district": "Orhaneli", "lat": 39.9027, "lon": 28.9867},
    {"name": "Orhangazi", "province": "Bursa", "district": "Orhangazi", "lat": 40.4955, "lon": 29.3108},
    {"name": "Osmangazi", "province": "Bursa", "district": "Osmangazi", "lat": 40.1982, "lon": 29.0612},
    {"name": "Yenişehir", "province": "Bursa", "district": "Yenişehir", "lat": 40.2626, "lon": 29.6522},
    {"name": "Yıldırım", "province": "Bursa", "district": "Yıldırım", "lat": 40.1866, "lon": 29.1282},
    {"name": "İnegöl", "province": "Bursa", "district": "İnegöl", "lat": 40.08, "lon": 29.5097},
    {"name": "İznik", "province": "Bursa", "district": "İznik", "lat": 40.4303, "lon": 29.7224},

    # DENIZLI
    {"name": "Acıpayam", "province": "Denizli", "district": "Acıpayam", "lat": 37.4274, "lon": 29.3505},
    {"name": "Akköy", "province": "Denizli", "district": "Akköy", "lat": 37.7627, "lon": 29.1017},
    {"name": "Babadağ", "province": "Denizli", "district": "Babadağ", "lat": 37.8077, "lon": 28.8564},
    {"name": "Baklan", "province": "Denizli", "district": "Baklan", "lat": 37.9768, "lon": 29.6067},
    {"name": "Bekilli", "province": "Denizli", "district": "Bekilli", "lat": 38.2295, "lon": 29.4208},
    {"name": "Beyağaç", "province": "Denizli", "district": "Beyağaç", "lat": 37.2357, "lon": 28.896},
    {"name": "Bozkurt", "province": "Denizli", "district": "Bozkurt", "lat": 37.8274, "lon": 29.6126},
    {"name": "Buldan", "province": "Denizli", "district": "Buldan", "lat": 38.0442, "lon": 28.8327},
    {"name": "Güney", "province": "Denizli", "district": "Güney", "lat": 38.1539, "lon": 29.0652},
    {"name": "Honaz", "province": "Denizli", "district": "Honaz", "lat": 37.7524, "lon": 29.2697},
    {"name": "Kale", "province": "Denizli", "district": "Kale", "lat": 37.4438, "lon": 28.8463},
    {"name": "Merkezefendi", "province": "Denizli", "district": "Merkezefendi", "lat": 37.7765, "lon": 29.0864},
    {"name": "Pamukkale", "province": "Denizli", "district": "Pamukkale", "lat": 37.9260, "lon": 29.1228},
    {"name": "Denizli", "province": "Denizli", "district": None, "lat": 37.7765, "lon": 29.0864},
    {"name": "Sarayköy", "province": "Denizli", "district": "Sarayköy", "lat": 37.9244, "lon": 28.9231},
    {"name": "Serinhisar", "province": "Denizli", "district": "Serinhisar", "lat": 37.5765, "lon": 29.2662},
    {"name": "Tavas", "province": "Denizli", "district": "Tavas", "lat": 37.5729, "lon": 29.0713},
    {"name": "Çal", "province": "Denizli", "district": "Çal", "lat": 38.0814, "lon": 29.3973},
    {"name": "Çameli", "province": "Denizli", "district": "Çameli", "lat": 37.0761, "lon": 29.3447},
    {"name": "Çardak", "province": "Denizli", "district": "Çardak", "lat": 37.8215, "lon": 29.6789},
    {"name": "Çivril", "province": "Denizli", "district": "Çivril", "lat": 38.3006, "lon": 29.7374},

    # DIYARBAKIR
    {"name": "Bismil", "province": "Diyarbakir", "district": "Bismil", "lat": 37.8528, "lon": 40.662},
    {"name": "Dicle", "province": "Diyarbakir", "district": "Dicle", "lat": 38.3728, "lon": 40.0718},
    {"name": "Ergani", "province": "Diyarbakir", "district": "Ergani", "lat": 38.2329, "lon": 39.755},
    {"name": "Eğil", "province": "Diyarbakir", "district": "Eğil", "lat": 38.2576, "lon": 40.0845},
    {"name": "Hani", "province": "Diyarbakir", "district": "Hani", "lat": 38.4116, "lon": 40.3951},
    {"name": "Hazro", "province": "Diyarbakir", "district": "Hazro", "lat": 38.2538, "lon": 40.7809},
    {"name": "Kocaköy", "province": "Diyarbakir", "district": "Kocaköy", "lat": 38.2906, "lon": 40.5043},
    {"name": "Kulp", "province": "Diyarbakir", "district": "Kulp", "lat": 38.5004, "lon": 41.012},
    {"name": "Lice", "province": "Diyarbakir", "district": "Lice", "lat": 38.4603, "lon": 40.6477},
    {"name": "Diyarbakir", "province": "Diyarbakir", "district": None, "lat": 37.9144, "lon": 40.2306},
    {"name": "Silvan", "province": "Diyarbakir", "district": "Silvan", "lat": 38.1412, "lon": 41.0056},
    {"name": "Çermik", "province": "Diyarbakir", "district": "Çermik", "lat": 38.1355, "lon": 39.4497},
    {"name": "Çüngüş", "province": "Diyarbakir", "district": "Çüngüş", "lat": 38.2118, "lon": 39.2881},
    {"name": "Çınar", "province": "Diyarbakir", "district": "Çınar", "lat": 37.7237, "lon": 40.4151},
    {"name": "Bağlar", "province": "Diyarbakir", "district": "Bağlar", "lat": 37.8964, "lon": 40.1864},
    {"name": "Kayapınar", "province": "Diyarbakir", "district": "Kayapınar", "lat": 37.9380, "lon": 40.1659},
    {"name": "Sur", "province": "Diyarbakir", "district": "Sur", "lat": 37.9129, "lon": 40.2339},
    {"name": "Yenişehir", "province": "Diyarbakir", "district": "Yenişehir", "lat": 37.9247, "lon": 40.2116},

    # DÜZCE
    {"name": "Akçakoca", "province": "Düzce", "district": "Akçakoca", "lat": 41.0882, "lon": 31.124},
    {"name": "Cumayeri", "province": "Düzce", "district": "Cumayeri", "lat": 40.8747, "lon": 30.9504},
    {"name": "Gölyaka", "province": "Düzce", "district": "Gölyaka", "lat": 40.7767, "lon": 30.9964},
    {"name": "Gümüşova", "province": "Düzce", "district": "Gümüşova", "lat": 40.8466, "lon": 30.9386},
    {"name": "Kaynaşlı", "province": "Düzce", "district": "Kaynaşlı", "lat": 40.7721, "lon": 31.3192},
    {"name": "Düzce", "province": "Düzce", "district": None, "lat": 40.8438, "lon": 31.1565},
    {"name": "Yığılca", "province": "Düzce", "district": "Yığılca", "lat": 40.96, "lon": 31.4447},
    {"name": "Çilimli", "province": "Düzce", "district": "Çilimli", "lat": 40.8933, "lon": 31.0466},

    # EDIRNE
    {"name": "Enez", "province": "Edirne", "district": "Enez", "lat": 40.725, "lon": 26.0846},
    {"name": "Havsa", "province": "Edirne", "district": "Havsa", "lat": 41.5493, "lon": 26.8206},
    {"name": "Keşan", "province": "Edirne", "district": "Keşan", "lat": 40.8549, "lon": 26.6303},
    {"name": "Lalapaşa", "province": "Edirne", "district": "Lalapaşa", "lat": 41.839, "lon": 26.7361},
    {"name": "Meriç", "province": "Edirne", "district": "Meriç", "lat": 41.6602, "lon": 26.5649},
    {"name": "Edirne", "province": "Edirne", "district": None, "lat": 41.6818, "lon": 26.5623},
    {"name": "Süleoğlu", "province": "Edirne", "district": "Süleoğlu", "lat": 41.7657, "lon": 26.908},
    {"name": "Uzunköprü", "province": "Edirne", "district": "Uzunköprü", "lat": 41.296, "lon": 26.6896},
    {"name": "İpsala", "province": "Edirne", "district": "İpsala", "lat": 40.9217, "lon": 26.384},

    # ELAZIĞ
    {"name": "Alacakaya", "province": "Elazığ", "district": "Alacakaya", "lat": 38.4622, "lon": 39.8625},
    {"name": "Aricak", "province": "Elazığ", "district": "Aricak", "lat": 38.5634, "lon": 40.1345},
    {"name": "Ağın", "province": "Elazığ", "district": "Ağın", "lat": 38.9439, "lon": 38.714},
    {"name": "Baskil", "province": "Elazığ", "district": "Baskil", "lat": 38.5677, "lon": 38.8232},
    {"name": "Karakoçan", "province": "Elazığ", "district": "Karakoçan", "lat": 38.9564, "lon": 40.038},
    {"name": "Keban", "province": "Elazığ", "district": "Keban", "lat": 38.7943, "lon": 38.7444},
    {"name": "Kovancılar", "province": "Elazığ", "district": "Kovancılar", "lat": 38.7189, "lon": 39.8659},
    {"name": "Maden", "province": "Elazığ", "district": "Maden", "lat": 38.4013, "lon": 39.669},
    {"name": "Elazığ", "province": "Elazığ", "district": None, "lat": 38.681, "lon": 39.2264},
    {"name": "Palu", "province": "Elazığ", "district": "Palu", "lat": 38.6935, "lon": 39.9289},
    {"name": "Sivrice", "province": "Elazığ", "district": "Sivrice", "lat": 38.4487, "lon": 39.3069},

    # ERZINCAN
    {"name": "Kemah", "province": "Erzincan", "district": "Kemah", "lat": 39.6036, "lon": 39.0337},
    {"name": "Kemaliye", "province": "Erzincan", "district": "Kemaliye", "lat": 39.2621, "lon": 38.4965},
    {"name": "Erzincan", "province": "Erzincan", "district": None, "lat": 39.75, "lon": 39.5},
    {"name": "Otlukbeli", "province": "Erzincan", "district": "Otlukbeli", "lat": 39.9719, "lon": 40.0217},
    {"name": "Refahiye", "province": "Erzincan", "district": "Refahiye", "lat": 39.9028, "lon": 38.7682},
    {"name": "Tercan", "province": "Erzincan", "district": "Tercan", "lat": 39.7765, "lon": 40.383},
    {"name": "Çayırlı", "province": "Erzincan", "district": "Çayırlı", "lat": 39.8041, "lon": 40.0372},
    {"name": "Üzümlü", "province": "Erzincan", "district": "Üzümlü", "lat": 39.7101, "lon": 39.701},
    {"name": "İliç", "province": "Erzincan", "district": "İliç", "lat": 39.4722, "lon": 38.5565},

    # ERZURUM
    {"name": "Aşkale", "province": "Erzurum", "district": "Aşkale", "lat": 39.9218, "lon": 40.6827},
    {"name": "Horasan", "province": "Erzurum", "district": "Horasan", "lat": 40.0408, "lon": 42.1625},
    {"name": "Hınıs", "province": "Erzurum", "district": "Hınıs", "lat": 39.3585, "lon": 41.7003},
    {"name": "Ilıca", "province": "Erzurum", "district": "Ilıca", "lat": 39.4246, "lon": 41.5677},
    {"name": "Karayazı", "province": "Erzurum", "district": "Karayazı", "lat": 39.7017, "lon": 42.1431},
    {"name": "Karaçoban", "province": "Erzurum", "district": "Karaçoban", "lat": 39.3505, "lon": 42.1116},
    {"name": "Köprüköy", "province": "Erzurum", "district": "Köprüköy", "lat": 39.9685, "lon": 41.8682},
    {"name": "Erzurum", "province": "Erzurum", "district": None, "lat": 39.9043, "lon": 41.2679},
    {"name": "Narman", "province": "Erzurum", "district": "Narman", "lat": 40.3452, "lon": 41.8711},
    {"name": "Oltu", "province": "Erzurum", "district": "Oltu", "lat": 40.5459, "lon": 41.996},
    {"name": "Olur", "province": "Erzurum", "district": "Olur", "lat": 40.8268, "lon": 42.1332},
    {"name": "Pasinler", "province": "Erzurum", "district": "Pasinler", "lat": 39.9773, "lon": 41.6745},
    {"name": "Pazaryolu", "province": "Erzurum", "district": "Pazaryolu", "lat": 40.4143, "lon": 40.7738},
    {"name": "Tekman", "province": "Erzurum", "district": "Tekman", "lat": 39.6467, "lon": 41.5094},
    {"name": "Tortum", "province": "Erzurum", "district": "Tortum", "lat": 40.2971, "lon": 41.5508},
    {"name": "Uzundere", "province": "Erzurum", "district": "Uzundere", "lat": 40.5327, "lon": 41.5483},
    {"name": "Çat", "province": "Erzurum", "district": "Çat", "lat": 39.6119, "lon": 40.9774},
    {"name": "İspir", "province": "Erzurum", "district": "İspir", "lat": 40.4834, "lon": 41.0},
    {"name": "Şenkaya", "province": "Erzurum", "district": "Şenkaya", "lat": 40.5611, "lon": 42.3453},

    # ESKISEHIR
    {"name": "Alpu", "province": "Eskisehir", "district": "Alpu", "lat": 39.768, "lon": 30.9541},
    {"name": "Beylikova", "province": "Eskisehir", "district": "Beylikova", "lat": 39.7042, "lon": 31.1893},
    {"name": "Günyüzü", "province": "Eskisehir", "district": "Günyüzü", "lat": 39.3843, "lon": 31.8097},
    {"name": "Han", "province": "Eskisehir", "district": "Han", "lat": 39.1584, "lon": 30.8634},
    {"name": "Mahmudiye", "province": "Eskisehir", "district": "Mahmudiye", "lat": 39.4947, "lon": 30.9876},
    {"name": "Eskisehir", "province": "Eskisehir", "district": None, "lat": 39.7767, "lon": 30.5206},
    {"name": "Mihalgazi", "province": "Eskisehir", "district": "Mihalgazi", "lat": 40.0264, "lon": 30.5782},
    {"name": "Mihalıçcık", "province": "Eskisehir", "district": "Mihalıçcık", "lat": 39.8666, "lon": 31.4961},
    {"name": "Sarıcakaya", "province": "Eskisehir", "district": "Sarıcakaya", "lat": 40.0389, "lon": 30.6189},
    {"name": "Seyitgazi", "province": "Eskisehir", "district": "Seyitgazi", "lat": 39.4443, "lon": 30.696},
    {"name": "Sivrihisar", "province": "Eskisehir", "district": "Sivrihisar", "lat": 39.451, "lon": 31.5368},
    {"name": "Çifteler", "province": "Eskisehir", "district": "Çifteler", "lat": 39.3757, "lon": 31.0379},
    {"name": "İnönü", "province": "Eskisehir", "district": "İnönü", "lat": 39.816, "lon": 30.1428},

    # GAZIANTEP
    {"name": "Gaziantep", "province": "Gaziantep", "district": None, "lat": 37.0662, "lon": 37.3783},
    {"name": "Araban", "province": "Gaziantep", "district": "Araban", "lat": 37.4253, "lon": 37.6894},
    {"name": "Karkamış", "province": "Gaziantep", "district": "Karkamış", "lat": 36.8308, "lon": 37.9998},
    {"name": "Nizip", "province": "Gaziantep", "district": "Nizip", "lat": 37.0013, "lon": 37.7889},
    {"name": "Nurdağı", "province": "Gaziantep", "district": "Nurdağı", "lat": 37.1779, "lon": 36.7409},
    {"name": "Oğuzeli", "province": "Gaziantep", "district": "Oğuzeli", "lat": 36.9651, "lon": 37.5085},
    {"name": "Yavuzeli", "province": "Gaziantep", "district": "Yavuzeli", "lat": 37.3179, "lon": 37.5669},
    {"name": "İslahiye", "province": "Gaziantep", "district": "İslahiye", "lat": 37.0307, "lon": 36.6367},
    {"name": "Şahinbey", "province": "Gaziantep", "district": "Şahinbey", "lat": 37.0576, "lon": 37.3794},
    {"name": "Şehitkamil", "province": "Gaziantep", "district": "Şehitkamil", "lat": 37.0728, "lon": 37.395},

    # GIRESUN
    {"name": "Alucra", "province": "Giresun", "district": "Alucra", "lat": 40.3197, "lon": 38.7652},
    {"name": "Bulancak", "province": "Giresun", "district": "Bulancak", "lat": 40.9389, "lon": 38.2319},
    {"name": "Dereli", "province": "Giresun", "district": "Dereli", "lat": 40.739, "lon": 38.4491},
    {"name": "Doğankent", "province": "Giresun", "district": "Doğankent", "lat": 40.8099, "lon": 38.9147},
    {"name": "Espiye", "province": "Giresun", "district": "Espiye", "lat": 40.9483, "lon": 38.7117},
    {"name": "Eynesil", "province": "Giresun", "district": "Eynesil", "lat": 41.0647, "lon": 39.1434},
    {"name": "Görele", "province": "Giresun", "district": "Görele", "lat": 41.0335, "lon": 38.9986},
    {"name": "Güce", "province": "Giresun", "district": "Güce", "lat": 40.894, "lon": 38.808},
    {"name": "Keşap", "province": "Giresun", "district": "Keşap", "lat": 40.9151, "lon": 38.5139},
    {"name": "Giresun", "province": "Giresun", "district": None, "lat": 40.9128, "lon": 38.3895},
    {"name": "Piraziz", "province": "Giresun", "district": "Piraziz", "lat": 40.9526, "lon": 38.1248},
    {"name": "Şebinkarahisar", "province": "Giresun", "district": "Şebinkarahisar", "lat": 40.2884, "lon": 38.4272, "code": "28016"},
    {"name": "Tirebolu", "province": "Giresun", "district": "Tirebolu", "lat": 41.0072, "lon": 38.8146},
    {"name": "Yağlıdere", "province": "Giresun", "district": "Yağlıdere", "lat": 40.8605, "lon": 38.6252},
    {"name": "Çamoluk", "province": "Giresun", "district": "Çamoluk", "lat": 40.1352, "lon": 38.734},
    {"name": "Çanakçı", "province": "Giresun", "district": "Çanakçı", "lat": 40.917, "lon": 39.0093},
    {"name": "Şultan Karahisar", "province": "Giresun", "district": "Şultan Karahisar", "lat": 40.2885, "lon": 38.4098},

    # GÜMÜSHANE
    {"name": "Kelkit", "province": "Gümüşhane", "district": "Kelkit", "lat": 40.1255, "lon": 39.436},
    {"name": "Köse", "province": "Gümüşhane", "district": "Köse", "lat": 40.2097, "lon": 39.653},
    {"name": "Kürtün", "province": "Gümüşhane", "district": "Kürtün", "lat": 40.7019, "lon": 39.0857},
    {"name": "Gümüşhane", "province": "Gümüşhane", "district": None, "lat": 40.4606, "lon": 39.4814},
    {"name": "Torul", "province": "Gümüşhane", "district": "Torul", "lat": 40.5577, "lon": 39.2926},
    {"name": "Şiran", "province": "Gümüşhane", "district": "Şiran", "lat": 40.1898, "lon": 39.1252},

    # HAKKARI
    {"name": "Hakkari", "province": "Hakkari", "district": None, "lat": 37.5744, "lon": 43.7408},
    {"name": "Yüksekova", "province": "Hakkari", "district": "Yüksekova", "lat": 37.5718, "lon": 44.2822},
    {"name": "Çukurca", "province": "Hakkari", "district": "Çukurca", "lat": 37.2468, "lon": 43.611},
    {"name": "Şemdinli", "province": "Hakkari", "district": "Şemdinli", "lat": 37.3061, "lon": 44.5736},
    {"name": "Derecik", "province": "Hakkari", "district": "Derecik", "lat": 37.1062, "lon": 44.3994},

    # HATAY
    {"name": "Altınözü", "province": "Hatay", "district": "Altınözü", "lat": 36.1143, "lon": 36.2496},
    {"name": "Belen", "province": "Hatay", "district": "Belen", "lat": 36.4917, "lon": 36.1944},
    {"name": "Dörtyol", "province": "Hatay", "district": "Dörtyol", "lat": 36.8353, "lon": 36.2274},
    {"name": "Erzin", "province": "Hatay", "district": "Erzin", "lat": 36.9746, "lon": 36.1305},
    {"name": "Hassa", "province": "Hatay", "district": "Hassa", "lat": 36.8001, "lon": 36.5172},
    {"name": "Kumlu", "province": "Hatay", "district": "Kumlu", "lat": 36.3648, "lon": 36.4541},
    {"name": "Kırıkhan", "province": "Hatay", "district": "Kırıkhan", "lat": 36.499, "lon": 36.3622},
    {"name": "Hatay", "province": "Hatay", "district": None, "lat": 36.2021, "lon": 36.1603},
    {"name": "Reyhanlı", "province": "Hatay", "district": "Reyhanlı", "lat": 36.2684, "lon": 36.5672},
    {"name": "Samandağ", "province": "Hatay", "district": "Samandağ", "lat": 36.0852, "lon": 35.9799},
    {"name": "Yayladağı", "province": "Hatay", "district": "Yayladağı", "lat": 35.903, "lon": 36.0626},
    {"name": "İskenderun", "province": "Hatay", "district": "İskenderun", "lat": 36.5902, "lon": 36.171},
    {"name": "Antakya", "province": "Hatay", "district": "Antakya", "lat": 36.2028, "lon": 36.1597},
    {"name": "Defne", "province": "Hatay", "district": "Defne", "lat": 36.2205, "lon": 36.1421},
    {"name": "Arsuz", "province": "Hatay", "district": "Arsuz", "lat": 36.3944, "lon": 35.8914},
    {"name": "Payas", "province": "Hatay", "district": "Payas", "lat": 36.7549, "lon": 36.2311},

    # ISPARTA
    {"name": "Aksu", "province": "Isparta", "district": "Aksu", "lat": 37.7989, "lon": 31.0711},
    {"name": "Atabey", "province": "Isparta", "district": "Atabey", "lat": 37.9509, "lon": 30.6374},
    {"name": "Eğirdir", "province": "Isparta", "district": "Eğirdir", "lat": 37.8741, "lon": 30.849},
    {"name": "Gelendost", "province": "Isparta", "district": "Gelendost", "lat": 38.1215, "lon": 31.0137},
    {"name": "Gönen", "province": "Isparta", "district": "Gönen", "lat": 37.9575, "lon": 30.5129},
    {"name": "Keçiborlu", "province": "Isparta", "district": "Keçiborlu", "lat": 37.9477, "lon": 30.307},
    {"name": "Isparta", "province": "Isparta", "district": None, "lat": 37.7648, "lon": 30.5566},
    {"name": "Senirkent", "province": "Isparta", "district": "Senirkent", "lat": 38.1078, "lon": 30.5503},
    {"name": "Sütçüler", "province": "Isparta", "district": "Sütçüler", "lat": 37.495, "lon": 30.9806},
    {"name": "Uluborlu", "province": "Isparta", "district": "Uluborlu", "lat": 38.0787, "lon": 30.4492},
    {"name": "Yalvaç", "province": "Isparta", "district": "Yalvaç", "lat": 38.3003, "lon": 31.1743},
    {"name": "Yenişarbademli", "province": "Isparta", "district": "Yenişarbademli", "lat": 37.7073, "lon": 31.3878},
    {"name": "Şarkikaraağaç", "province": "Isparta", "district": "Şarkikaraağaç", "lat": 38.0807, "lon": 31.3661},

    # ISTANBUL
    {"name": "Istanbul", "province": "Istanbul", "district": None, "lat": 41.0082, "lon": 28.9784},
    {"name": "Adalar", "province": "Istanbul", "district": "Adalar", "lat": 40.8742, "lon": 29.1293},
    {"name": "Arnavutkoy", "province": "Istanbul", "district": "Arnavutkoy", "lat": 41.1845, "lon": 28.7412},
    {"name": "Atasehir", "province": "Istanbul", "district": "Atasehir", "lat": 40.9929, "lon": 29.1135},
    {"name": "Avcılar", "province": "Istanbul", "district": "Avcılar", "lat": 40.9799, "lon": 28.7217},
    {"name": "Bahçelievler", "province": "Istanbul", "district": "Bahçelievler", "lat": 41.003, "lon": 28.8658},
    {"name": "Bakırköy", "province": "Istanbul", "district": "Bakırköy", "lat": 40.9783, "lon": 28.8744},
    {"name": "Basaksehir", "province": "Istanbul", "district": "Basaksehir", "lat": 41.1076, "lon": 28.7951},
    {"name": "Bayrampaşa", "province": "Istanbul", "district": "Bayrampaşa", "lat": 41.0346, "lon": 28.9118},
    {"name": "Bağcılar", "province": "Istanbul", "district": "Bağcılar", "lat": 41.0345, "lon": 28.8568},
    {"name": "Beykoz", "province": "Istanbul", "district": "Beykoz", "lat": 41.1343, "lon": 29.092},
    {"name": "Beylikduzu", "province": "Istanbul", "district": "Beylikduzu", "lat": 41.0038, "lon": 28.6373},
    {"name": "Beyoğlu", "province": "Istanbul", "district": "Beyoğlu", "lat": 41.0284, "lon": 28.9737},
    {"name": "Beşiktaş", "province": "Istanbul", "district": "Beşiktaş", "lat": 41.0428, "lon": 29.0075},
    {"name": "Büyükçekmece", "province": "Istanbul", "district": "Büyükçekmece", "lat": 41.0217, "lon": 28.5798},
    {"name": "Esenler", "province": "Istanbul", "district": "Esenler", "lat": 41.0376, "lon": 28.8825},
    {"name": "Eyüpsultan", "province": "Istanbul", "district": "Eyüpsultan", "lat": 41.0488, "lon": 28.9344, "code": "34040"},
    {"name": "Esenyurt", "province": "Istanbul", "district": "Esenyurt", "lat": 41.0343, "lon": 28.6801},
    {"name": "Eyüp", "province": "Istanbul", "district": "Eyüp", "lat": 41.0478, "lon": 28.9327},
    {"name": "Fatih", "province": "Istanbul", "district": "Fatih", "lat": 41.0193, "lon": 28.9479},
    {"name": "Gaziosmanpaşa", "province": "Istanbul", "district": "Gaziosmanpaşa", "lat": 41.0578, "lon": 28.9122},
    {"name": "Güngören", "province": "Istanbul", "district": "Güngören", "lat": 41.0253, "lon": 28.8726},
    {"name": "Kadıköy", "province": "Istanbul", "district": "Kadıköy", "lat": 40.9913, "lon": 29.0246},
    {"name": "Kartal", "province": "Istanbul", "district": "Kartal", "lat": 40.8886, "lon": 29.1857},
    {"name": "Kağıthane", "province": "Istanbul", "district": "Kağıthane", "lat": 41.0797, "lon": 28.9731},
    {"name": "Küçükçekmece", "province": "Istanbul", "district": "Küçükçekmece", "lat": 40.9919, "lon": 28.7712},
    {"name": "Maltepe", "province": "Istanbul", "district": "Maltepe", "lat": 40.9248, "lon": 29.1311},
    {"name": "Pendik", "province": "Istanbul", "district": "Pendik", "lat": 40.8769, "lon": 29.235},
    {"name": "Sancaktepe", "province": "Istanbul", "district": "Sancaktepe", "lat": 40.9905, "lon": 29.2289},
    {"name": "Sarıyer", "province": "Istanbul", "district": "Sarıyer", "lat": 41.1686, "lon": 29.0573},
    {"name": "Silivri", "province": "Istanbul", "district": "Silivri", "lat": 41.0742, "lon": 28.2482},
    {"name": "Sultanbeyli", "province": "Istanbul", "district": "Sultanbeyli", "lat": 40.967, "lon": 29.2671},
    {"name": "Sultangazi", "province": "Istanbul", "district": "Sultangazi", "lat": 41.1043, "lon": 28.8614},
    {"name": "Tuzla", "province": "Istanbul", "district": "Tuzla", "lat": 40.8162, "lon": 29.3034},
    {"name": "Zeytinburnu", "province": "Istanbul", "district": "Zeytinburnu", "lat": 40.9899, "lon": 28.9037},
    {"name": "Çatalca", "province": "Istanbul", "district": "Çatalca", "lat": 41.1437, "lon": 28.4605},
    {"name": "Çekmekoy", "province": "Istanbul", "district": "Çekmekoy", "lat": 41.0352, "lon": 29.1739},
    {"name": "Ümraniye", "province": "Istanbul", "district": "Ümraniye", "lat": 41.0256, "lon": 29.0963},
    {"name": "Üsküdar", "province": "Istanbul", "district": "Üsküdar", "lat": 41.0265, "lon": 29.0151},
    {"name": "Şile", "province": "Istanbul", "district": "Şile", "lat": 41.1744, "lon": 29.6125},
    {"name": "Şişli", "province": "Istanbul", "district": "Şişli", "lat": 41.0638, "lon": 28.9832},

    # IZMIR
    {"name": "Izmir", "province": "Izmir", "district": None, "lat": 38.4237, "lon": 27.1428},
    {"name": "Aliağa", "province": "Izmir", "district": "Aliağa", "lat": 38.8034, "lon": 26.9714},
    {"name": "Balçova", "province": "Izmir", "district": "Balçova", "lat": 38.3953, "lon": 27.0579},
    {"name": "Bayındır", "province": "Izmir", "district": "Bayındır", "lat": 38.22, "lon": 27.6484},
    {"name": "Bergama", "province": "Izmir", "district": "Bergama", "lat": 39.1189, "lon": 27.1774},
    {"name": "Beydağ", "province": "Izmir", "district": "Beydağ", "lat": 38.087, "lon": 28.2107},
    {"name": "Bornova", "province": "Izmir", "district": "Bornova", "lat": 38.4662, "lon": 27.2192},
    {"name": "Bayraklı", "province": "Izmir", "district": "Bayraklı", "lat": 38.4592, "lon": 27.1647, "code": "35029"},
    {"name": "Buca", "province": "Izmir", "district": "Buca", "lat": 38.388, "lon": 27.1734},
    {"name": "Dikili", "province": "Izmir", "district": "Dikili", "lat": 39.075, "lon": 26.8892},
    {"name": "Foça", "province": "Izmir", "district": "Foça", "lat": 38.6689, "lon": 26.7548},
    {"name": "Gaziemir", "province": "Izmir", "district": "Gaziemir", "lat": 38.3263, "lon": 27.14},
    {"name": "Karabağlar", "province": "Izmir", "district": "Karabağlar", "lat": 38.3726, "lon": 27.1172, "code": "35030"},
    {"name": "Güzelbahçe", "province": "Izmir", "district": "Güzelbahçe", "lat": 38.3755, "lon": 26.8756},
    {"name": "Karaburun", "province": "Izmir", "district": "Karaburun", "lat": 38.297, "lon": 26.6931},
    {"name": "Karşıyaka", "province": "Izmir", "district": "Karşıyaka", "lat": 38.5034, "lon": 27.1135},
    {"name": "Kemalpaşa", "province": "Izmir", "district": "Kemalpaşa", "lat": 38.4276, "lon": 27.4164},
    {"name": "Kiraz", "province": "Izmir", "district": "Kiraz", "lat": 38.2304, "lon": 28.2016},
    {"name": "Konak", "province": "Izmir", "district": "Konak", "lat": 38.4187, "lon": 27.1283},
    {"name": "Kınık", "province": "Izmir", "district": "Kınık", "lat": 39.0876, "lon": 27.3805},
    {"name": "Menderes", "province": "Izmir", "district": "Menderes", "lat": 38.2552, "lon": 27.1381},
    {"name": "Menemen", "province": "Izmir", "district": "Menemen", "lat": 38.6082, "lon": 27.0861},
    {"name": "Narlıdere", "province": "Izmir", "district": "Narlıdere", "lat": 38.3954, "lon": 27.0011},
    {"name": "Seferihisar", "province": "Izmir", "district": "Seferihisar", "lat": 38.195, "lon": 26.8342},
    {"name": "Selçuk", "province": "Izmir", "district": "Selçuk", "lat": 37.948, "lon": 27.3685},
    {"name": "Tire", "province": "Izmir", "district": "Tire", "lat": 38.0895, "lon": 27.7318},
    {"name": "Torbalı", "province": "Izmir", "district": "Torbalı", "lat": 38.1514, "lon": 27.3616},
    {"name": "Urla", "province": "Izmir", "district": "Urla", "lat": 38.3173, "lon": 26.7823},
    {"name": "Çeşme", "province": "Izmir", "district": "Çeşme", "lat": 38.3244, "lon": 26.303},
    {"name": "Çiğli", "province": "Izmir", "district": "Çiğli", "lat": 38.4944, "lon": 27.0616},
    {"name": "Ödemiş", "province": "Izmir", "district": "Ödemiş", "lat": 38.2221, "lon": 27.9656},

    # IĞDIR
    {"name": "Aralık", "province": "Iğdır", "district": "Aralık", "lat": 39.8737, "lon": 44.516},
    {"name": "Karakoyunlu", "province": "Iğdır", "district": "Karakoyunlu", "lat": 39.9711, "lon": 44.1737},
    {"name": "Iğdır", "province": "Iğdır", "district": None, "lat": 39.9227, "lon": 44.045},
    {"name": "Tuzluca", "province": "Iğdır", "district": "Tuzluca", "lat": 40.0402, "lon": 43.6638},

    # K. MARAS
    {"name": "Afşin", "province": "K. Maras", "district": "Afşin", "lat": 38.2439, "lon": 36.9153},
    {"name": "Andırın", "province": "K. Maras", "district": "Andırın", "lat": 37.575, "lon": 36.3552},
    {"name": "Ekinözü", "province": "K. Maras", "district": "Ekinözü", "lat": 38.0607, "lon": 37.1894},
    {"name": "Elbistan", "province": "K. Maras", "district": "Elbistan", "lat": 38.2022, "lon": 37.1903},
    {"name": "Göksun", "province": "K. Maras", "district": "Göksun", "lat": 38.0213, "lon": 36.4946},
    {"name": "K. Maras", "province": "K. Maras", "district": None, "lat": 37.5858, "lon": 36.9371},
    {"name": "Dulkadiroğlu", "province": "K. Maras", "district": "Dulkadiroğlu", "lat": 37.5753, "lon": 36.9228, "code": "46010"},
    {"name": "Nurhak", "province": "K. Maras", "district": "Nurhak", "lat": 37.9661, "lon": 37.4422},
    {"name": "Onikişubat", "province": "K. Maras", "district": "Onikişubat", "lat": 37.5847, "lon": 36.9372, "code": "46011"},
    {"name": "Pazarcık", "province": "K. Maras", "district": "Pazarcık", "lat": 37.4895, "lon": 37.2935},
    {"name": "Türkoğlu", "province": "K. Maras", "district": "Türkoğlu", "lat": 37.3865, "lon": 36.8474},
    {"name": "Çağlayancerit", "province": "K. Maras", "district": "Çağlayancerit", "lat": 37.75, "lon": 37.2928},

    # KARABÜK
    {"name": "Eflani", "province": "Karabük", "district": "Eflani", "lat": 41.4229, "lon": 32.9582},
    {"name": "Eskipazar", "province": "Karabük", "district": "Eskipazar", "lat": 40.9568, "lon": 32.5335},
    {"name": "Karabük", "province": "Karabük", "district": None, "lat": 41.1992, "lon": 32.6275},
    {"name": "Ovacık", "province": "Karabük", "district": "Ovacık", "lat": 41.0759, "lon": 32.92},
    {"name": "Safranbolu", "province": "Karabük", "district": "Safranbolu", "lat": 41.2457, "lon": 32.693},
    {"name": "Yenice", "province": "Karabük", "district": "Yenice", "lat": 41.2007, "lon": 32.3279},

    # KARAMAN
    {"name": "Ayrancı", "province": "Karaman", "district": "Ayrancı", "lat": 37.3711, "lon": 33.6663},
    {"name": "Başyayla", "province": "Karaman", "district": "Başyayla", "lat": 36.753, "lon": 32.6798},
    {"name": "Ermenek", "province": "Karaman", "district": "Ermenek", "lat": 36.6389, "lon": 32.8889},
    {"name": "Kazımkarabekir", "province": "Karaman", "district": "Kazımkarabekir", "lat": 37.2492, "lon": 32.9517},
    {"name": "Karaman", "province": "Karaman", "district": None, "lat": 37.1759, "lon": 33.2287},
    {"name": "Sarıveliler", "province": "Karaman", "district": "Sarıveliler", "lat": 36.6985, "lon": 32.6182},

    # KARS
    {"name": "Akyaka", "province": "Kars", "district": "Akyaka", "lat": 40.7398, "lon": 43.6234},
    {"name": "Arpaçay", "province": "Kars", "district": "Arpaçay", "lat": 40.8464, "lon": 43.329},
    {"name": "Digor", "province": "Kars", "district": "Digor", "lat": 40.3765, "lon": 43.4119},
    {"name": "Kağızman", "province": "Kars", "district": "Kağızman", "lat": 40.1407, "lon": 43.1205},
    {"name": "Kars", "province": "Kars", "district": None, "lat": 40.6013, "lon": 43.0975},
    {"name": "Sarıkamış", "province": "Kars", "district": "Sarıkamış", "lat": 40.3359, "lon": 42.5769},
    {"name": "Selim", "province": "Kars", "district": "Selim", "lat": 40.4336, "lon": 42.8041},
    {"name": "Susuz", "province": "Kars", "district": "Susuz", "lat": 40.7792, "lon": 43.1287},

    # KASTAMONU
    {"name": "Abana", "province": "Kastamonu", "district": "Abana", "lat": 41.9785, "lon": 34.0077},
    {"name": "Araç", "province": "Kastamonu", "district": "Araç", "lat": 41.2412, "lon": 33.3249},
    {"name": "Azdavay", "province": "Kastamonu", "district": "Azdavay", "lat": 41.6421, "lon": 33.3009},
    {"name": "Ağlı", "province": "Kastamonu", "district": "Ağlı", "lat": 41.6872, "lon": 33.5538},
    {"name": "Bozkurt", "province": "Kastamonu", "district": "Bozkurt", "lat": 41.9588, "lon": 34.0126},
    {"name": "Cide", "province": "Kastamonu", "district": "Cide", "lat": 41.8916, "lon": 33.0037},
    {"name": "Daday", "province": "Kastamonu", "district": "Daday", "lat": 41.4752, "lon": 33.4637},
    {"name": "Devrekani", "province": "Kastamonu", "district": "Devrekani", "lat": 41.6026, "lon": 33.8371},
    {"name": "Doğanyurt", "province": "Kastamonu", "district": "Doğanyurt", "lat": 42.0056, "lon": 33.4605},
    {"name": "Hanönü", "province": "Kastamonu", "district": "Hanönü", "lat": 41.6256, "lon": 34.468},
    {"name": "Küre", "province": "Kastamonu", "district": "Küre", "lat": 41.8059, "lon": 33.7103},
    {"name": "Kastamonu", "province": "Kastamonu", "district": None, "lat": 41.3887, "lon": 33.7827},
    {"name": "Pınarbası", "province": "Kastamonu", "district": "Pınarbası", "lat": 41.6036, "lon": 33.1109},
    {"name": "Seydiler", "province": "Kastamonu", "district": "Seydiler", "lat": 41.6188, "lon": 33.7186},
    {"name": "Taşköprü", "province": "Kastamonu", "district": "Taşköprü", "lat": 41.5075, "lon": 34.2128},
    {"name": "Tosya", "province": "Kastamonu", "district": "Tosya", "lat": 41.0165, "lon": 34.0386},
    {"name": "Çatalzeytin", "province": "Kastamonu", "district": "Çatalzeytin", "lat": 41.9531, "lon": 34.2227},
    {"name": "İhsangazi", "province": "Kastamonu", "district": "İhsangazi", "lat": 41.204, "lon": 33.5559},
    {"name": "İnebolu", "province": "Kastamonu", "district": "İnebolu", "lat": 41.9786, "lon": 33.7599},
    {"name": "Şenpazar", "province": "Kastamonu", "district": "Şenpazar", "lat": 41.8086, "lon": 33.2329},

    # KAYSERI
    {"name": "Kayseri", "province": "Kayseri", "district": None, "lat": 38.7312, "lon": 35.4787},
    {"name": "Akkışla", "province": "Kayseri", "district": "Akkışla", "lat": 39.0015, "lon": 36.171},
    {"name": "Bünyan", "province": "Kayseri", "district": "Bünyan", "lat": 38.8458, "lon": 35.8577},
    {"name": "Develi", "province": "Kayseri", "district": "Develi", "lat": 38.3879, "lon": 35.4901},
    {"name": "Felahiye", "province": "Kayseri", "district": "Felahiye", "lat": 39.0907, "lon": 35.5675},
    {"name": "Hacılar", "province": "Kayseri", "district": "Hacılar", "lat": 38.6443, "lon": 35.4498},
    {"name": "Kocasinan", "province": "Kayseri", "district": "Kocasinan", "lat": 38.7363, "lon": 35.495},
    {"name": "Melikgazi", "province": "Kayseri", "district": "Melikgazi", "lat": 38.7199, "lon": 35.5057},
    {"name": "Pınarbaşı", "province": "Kayseri", "district": "Pınarbaşı", "lat": 38.7214, "lon": 36.3941},
    {"name": "Sarıoğlan", "province": "Kayseri", "district": "Sarıoğlan", "lat": 39.0771, "lon": 35.9672},
    {"name": "Sarız", "province": "Kayseri", "district": "Sarız", "lat": 38.4802, "lon": 36.497},
    {"name": "Talas", "province": "Kayseri", "district": "Talas", "lat": 38.6908, "lon": 35.5519},
    {"name": "Tomarza", "province": "Kayseri", "district": "Tomarza", "lat": 38.4477, "lon": 35.8009},
    {"name": "Yahyalı", "province": "Kayseri", "district": "Yahyalı", "lat": 38.1003, "lon": 35.3541},
    {"name": "Yeşilhisar", "province": "Kayseri", "district": "Yeşilhisar", "lat": 38.3653, "lon": 35.0844},
    {"name": "Özvatan", "province": "Kayseri", "district": "Özvatan", "lat": 39.1059, "lon": 35.6992},
    {"name": "İncesu", "province": "Kayseri", "district": "İncesu", "lat": 38.6288, "lon": 35.1965},

    # KILIS
    {"name": "Elbeyli", "province": "Kilis", "district": "Elbeyli", "lat": 36.675, "lon": 37.4669},
    {"name": "Kilis", "province": "Kilis", "district": None, "lat": 36.7184, "lon": 37.1212},
    {"name": "Musabeyli", "province": "Kilis", "district": "Musabeyli", "lat": 36.8861, "lon": 36.9156},
    {"name": "Polateli", "province": "Kilis", "district": "Polateli", "lat": 36.8408, "lon": 37.1429},

    # KINKKALE
    {"name": "Bahşılı", "province": "Kırıkkale", "district": "Bahşılı", "lat": 40.1019, "lon": 34.1157},
    {"name": "Balışeyh", "province": "Kırıkkale", "district": "Balışeyh", "lat": 39.9097, "lon": 33.7183},
    {"name": "Delice", "province": "Kırıkkale", "district": "Delice", "lat": 39.6886, "lon": 28.6628},
    {"name": "Karakeçili", "province": "Kırıkkale", "district": "Karakeçili", "lat": 40.5435, "lon": 34.6456},
    {"name": "Keskin", "province": "Kırıkkale", "district": "Keskin", "lat": 39.674, "lon": 33.6152},
    {"name": "Kırıkkale", "province": "Kırıkkale", "district": None, "lat": 39.8468, "lon": 33.5154},
    {"name": "Sulakyurt", "province": "Kırıkkale", "district": "Sulakyurt", "lat": 41.1626, "lon": 42.6232},
    {"name": "Yahşihan", "province": "Kırıkkale", "district": "Yahşihan", "lat": 39.8498, "lon": 33.4524},
    {"name": "Çelebi", "province": "Kırıkkale", "district": "Çelebi", "lat": 39.1304, "lon": 40.2694},

    # KIRKLARELI
    {"name": "Babaeski", "province": "Kirklareli", "district": "Babaeski", "lat": 41.4303, "lon": 27.0918},
    {"name": "Demirköy", "province": "Kirklareli", "district": "Demirköy", "lat": 41.8242, "lon": 27.7651},
    {"name": "Kofçaz", "province": "Kirklareli", "district": "Kofçaz", "lat": 41.945, "lon": 27.1579},
    {"name": "Lüleburgaz", "province": "Kirklareli", "district": "Lüleburgaz", "lat": 41.4041, "lon": 27.3555},
    {"name": "Kirklareli", "province": "Kirklareli", "district": None, "lat": 41.7351, "lon": 27.2253},
    {"name": "Pehlivanköy", "province": "Kirklareli", "district": "Pehlivanköy", "lat": 41.346, "lon": 26.9182},
    {"name": "Pınarhisar", "province": "Kirklareli", "district": "Pınarhisar", "lat": 41.6255, "lon": 27.5158},
    {"name": "Vize", "province": "Kirklareli", "district": "Vize", "lat": 41.5729, "lon": 27.767},

    # KIRSEHIR
    {"name": "Akpınar", "province": "Kirsehir", "district": "Akpınar", "lat": 39.448, "lon": 33.9639},
    {"name": "Akçakent", "province": "Kirsehir", "district": "Akçakent", "lat": 39.625, "lon": 34.0962},
    {"name": "Boztepe", "province": "Kirsehir", "district": "Boztepe", "lat": 39.2716, "lon": 34.264},
    {"name": "Kaman", "province": "Kirsehir", "district": "Kaman", "lat": 39.3589, "lon": 33.7244},
    {"name": "Kirsehir", "province": "Kirsehir", "district": None, "lat": 39.1425, "lon": 34.1709},
    {"name": "Mucur", "province": "Kirsehir", "district": "Mucur", "lat": 39.0602, "lon": 34.38},
    {"name": "Çiçekdağı", "province": "Kirsehir", "district": "Çiçekdağı", "lat": 39.6036, "lon": 34.4158},

    # KOCAELI
    {"name": "Başiskele", "province": "Kocaeli", "district": "Başiskele", "lat": 40.7607, "lon": 29.8708},
    {"name": "Çayırova", "province": "Kocaeli", "district": "Çayırova", "lat": 40.7867, "lon": 29.4167},
    {"name": "Darıca", "province": "Kocaeli", "district": "Darıca", "lat": 40.7656, "lon": 29.3792},
    {"name": "Derince", "province": "Kocaeli", "district": "Derince", "lat": 40.7574, "lon": 29.8308},
    {"name": "Dilovası", "province": "Kocaeli", "district": "Dilovası", "lat": 40.7789, "lon": 29.5167},
    {"name": "Gebze", "province": "Kocaeli", "district": "Gebze", "lat": 40.8007, "lon": 29.4318},
    {"name": "Gölcük", "province": "Kocaeli", "district": "Gölcük", "lat": 40.7169, "lon": 29.8196},
    {"name": "Kandıra", "province": "Kocaeli", "district": "Kandıra", "lat": 41.0704, "lon": 30.1523},
    {"name": "Karamürsel", "province": "Kocaeli", "district": "Karamürsel", "lat": 40.6913, "lon": 29.6166},
    {"name": "Kartepe", "province": "Kocaeli", "district": "Kartepe", "lat": 40.6991, "lon": 29.8953},
    {"name": "Körfez", "province": "Kocaeli", "district": "Körfez", "lat": 40.7608, "lon": 29.7839},
    {"name": "İzmit", "province": "Kocaeli", "district": "İzmit", "lat": 40.7700, "lon": 29.9400},
    {"name": "Kocaeli", "province": "Kocaeli", "district": None, "lat": 40.7654, "lon": 29.9408},

    # KONYA
    {"name": "Konya", "province": "Konya", "district": None, "lat": 37.8667, "lon": 32.4833},
    {"name": "Ahırlı", "province": "Konya", "district": "Ahırlı", "lat": 37.2387, "lon": 32.1189},
    {"name": "Akören", "province": "Konya", "district": "Akören", "lat": 37.4523, "lon": 32.3725},
    {"name": "Akşehir", "province": "Konya", "district": "Akşehir", "lat": 38.3589, "lon": 31.4202},
    {"name": "Altınekin", "province": "Konya", "district": "Altınekin", "lat": 38.3073, "lon": 32.8691},
    {"name": "Beyşehir", "province": "Konya", "district": "Beyşehir", "lat": 37.6755, "lon": 31.7269},
    {"name": "Bozkır", "province": "Konya", "district": "Bozkır", "lat": 37.1899, "lon": 32.2472},
    {"name": "Cihanbeyli", "province": "Konya", "district": "Cihanbeyli", "lat": 38.659, "lon": 32.9237},
    {"name": "Derbent", "province": "Konya", "district": "Derbent", "lat": 38.0137, "lon": 32.0172},
    {"name": "Derebucak", "province": "Konya", "district": "Derebucak", "lat": 37.3915, "lon": 31.5107},
    {"name": "Doğanhisar", "province": "Konya", "district": "Doğanhisar", "lat": 38.146, "lon": 31.6769},
    {"name": "Emirgazi", "province": "Konya", "district": "Emirgazi", "lat": 37.9035, "lon": 33.836},
    {"name": "Ereğli", "province": "Konya", "district": "Ereğli", "lat": 37.5141, "lon": 34.0473},
    {"name": "Güneysınır", "province": "Konya", "district": "Güneysınır", "lat": 37.2981, "lon": 32.7211},
    {"name": "Hadım", "province": "Konya", "district": "Hadım", "lat": 36.9861, "lon": 32.4558},
    {"name": "Halkapınar", "province": "Konya", "district": "Halkapınar", "lat": 37.4335, "lon": 34.1866},
    {"name": "Hüyük", "province": "Konya", "district": "Hüyük", "lat": 37.9548, "lon": 31.5973},
    {"name": "Ilgın", "province": "Konya", "district": "Ilgın", "lat": 38.2818, "lon": 31.9179},
    {"name": "Kadınhanı", "province": "Konya", "district": "Kadınhanı", "lat": 38.2401, "lon": 32.2122},
    {"name": "Karapınar", "province": "Konya", "district": "Karapınar", "lat": 37.7178, "lon": 33.5476},
    {"name": "Karatay", "province": "Konya", "district": "Karatay", "lat": 37.871, "lon": 32.503},
    {"name": "Kulu", "province": "Konya", "district": "Kulu", "lat": 39.0371, "lon": 33.0286},
    {"name": "Meram", "province": "Konya", "district": "Meram", "lat": 37.868, "lon": 32.4947},
    {"name": "Sarayönü", "province": "Konya", "district": "Sarayönü", "lat": 38.2559, "lon": 32.404},
    {"name": "Selçuklu", "province": "Konya", "district": "Selçuklu", "lat": 37.8769, "lon": 32.4874},
    {"name": "Seydişehir", "province": "Konya", "district": "Seydişehir", "lat": 37.4194, "lon": 31.8483},
    {"name": "Taşkent", "province": "Konya", "district": "Taşkent", "lat": 36.9239, "lon": 32.4926},
    {"name": "Tuzlukçu", "province": "Konya", "district": "Tuzlukçu", "lat": 38.4729, "lon": 31.6271},
    {"name": "Yalıhüyük", "province": "Konya", "district": "Yalıhüyük", "lat": 37.3006, "lon": 32.0854},
    {"name": "Yunak", "province": "Konya", "district": "Yunak", "lat": 38.818, "lon": 32.014},
    {"name": "Çeltik", "province": "Konya", "district": "Çeltik", "lat": 39.0016, "lon": 31.8468},
    {"name": "Çumra", "province": "Konya", "district": "Çumra", "lat": 37.572, "lon": 32.7846},

    # KÜTAHYA
    {"name": "Altıntaş", "province": "Kütahya", "district": "Altıntaş", "lat": 39.0604, "lon": 30.1076},
    {"name": "Aslanapa", "province": "Kütahya", "district": "Aslanapa", "lat": 39.2152, "lon": 29.8696},
    {"name": "Domaniç", "province": "Kütahya", "district": "Domaniç", "lat": 39.8132, "lon": 29.5165},
    {"name": "Dumlupınar", "province": "Kütahya", "district": "Dumlupınar", "lat": 38.8544, "lon": 29.9776},
    {"name": "Emet", "province": "Kütahya", "district": "Emet", "lat": 39.3415, "lon": 29.2586},
    {"name": "Gediz", "province": "Kütahya", "district": "Gediz", "lat": 38.9898, "lon": 29.394},
    {"name": "Hisarcık", "province": "Kütahya", "district": "Hisarcık", "lat": 39.2505, "lon": 29.2313},
    {"name": "Kütahya", "province": "Kütahya", "district": None, "lat": 39.4242, "lon": 29.9835},
    {"name": "Pazarlar", "province": "Kütahya", "district": "Pazarlar", "lat": 38.9946, "lon": 29.1231},
    {"name": "Simav", "province": "Kütahya", "district": "Simav", "lat": 39.0887, "lon": 28.98},
    {"name": "Tavşanlı", "province": "Kütahya", "district": "Tavşanlı", "lat": 39.5451, "lon": 29.4955},
    {"name": "Çavdarhisar", "province": "Kütahya", "district": "Çavdarhisar", "lat": 39.1944, "lon": 29.6195},
    {"name": "Şaphane", "province": "Kütahya", "district": "Şaphane", "lat": 39.0254, "lon": 29.22},

    # MALATYA
    {"name": "Akçadağ", "province": "Malatya", "district": "Akçadağ", "lat": 38.3444, "lon": 37.9711},
    {"name": "Arapkir", "province": "Malatya", "district": "Arapkir", "lat": 39.0422, "lon": 38.4898},
    {"name": "Arguvan", "province": "Malatya", "district": "Arguvan", "lat": 38.7821, "lon": 38.2643},
    {"name": "Battalgazi", "province": "Malatya", "district": "Battalgazi", "lat": 38.425, "lon": 38.3655},
    {"name": "Darende", "province": "Malatya", "district": "Darende", "lat": 38.5573, "lon": 37.4927},
    {"name": "Doğanyol", "province": "Malatya", "district": "Doğanyol", "lat": 38.3097, "lon": 39.0384},
    {"name": "Doğanşehir", "province": "Malatya", "district": "Doğanşehir", "lat": 38.0934, "lon": 37.8784},
    {"name": "Hekimhan", "province": "Malatya", "district": "Hekimhan", "lat": 38.91, "lon": 37.883},
    {"name": "Kale", "province": "Malatya", "district": "Kale", "lat": 38.4175, "lon": 38.7687},
    {"name": "Kuluncak", "province": "Malatya", "district": "Kuluncak", "lat": 38.8659, "lon": 37.7158},
    {"name": "Malatya", "province": "Malatya", "district": None, "lat": 38.3552, "lon": 38.3095},
    {"name": "Pötürge", "province": "Malatya", "district": "Pötürge", "lat": 38.1973, "lon": 38.8702},
    {"name": "Yazıhan", "province": "Malatya", "district": "Yazıhan", "lat": 38.5957, "lon": 38.1801},
    {"name": "Yeşilyurt", "province": "Malatya", "district": "Yeşilyurt", "lat": 38.2955, "lon": 38.2475},

    # MANISA
    {"name": "Ahmetli", "province": "Manisa", "district": "Ahmetli", "lat": 38.5203, "lon": 27.9386},
    {"name": "Akhisar", "province": "Manisa", "district": "Akhisar", "lat": 38.9241, "lon": 27.8402},
    {"name": "Alaşehir", "province": "Manisa", "district": "Alaşehir", "lat": 38.3507, "lon": 28.5166},
    {"name": "Demirci", "province": "Manisa", "district": "Demirci", "lat": 39.0474, "lon": 28.6584},
    {"name": "Gölmarmara", "province": "Manisa", "district": "Gölmarmara", "lat": 38.7122, "lon": 27.9157},
    {"name": "Gördes", "province": "Manisa", "district": "Gördes", "lat": 38.933, "lon": 28.2886},
    {"name": "Kula", "province": "Manisa", "district": "Kula", "lat": 38.5469, "lon": 28.6474},
    {"name": "Köprübaşı", "province": "Manisa", "district": "Köprübaşı", "lat": 38.748, "lon": 28.403},
    {"name": "Kırkağaç", "province": "Manisa", "district": "Kırkağaç", "lat": 39.1155, "lon": 27.686},
    {"name": "Manisa", "province": "Manisa", "district": None, "lat": 38.6191, "lon": 27.4289},
    {"name": "Salihli", "province": "Manisa", "district": "Salihli", "lat": 38.4829, "lon": 28.1309},
    {"name": "Saruhanlı", "province": "Manisa", "district": "Saruhanlı", "lat": 38.7327, "lon": 27.5774},
    {"name": "Sarıgöl", "province": "Manisa", "district": "Sarıgöl", "lat": 38.2382, "lon": 28.6966},
    {"name": "Selendi", "province": "Manisa", "district": "Selendi", "lat": 38.7434, "lon": 28.8702},
    {"name": "Soma", "province": "Manisa", "district": "Soma", "lat": 39.1987, "lon": 27.6242},
    {"name": "Turgutlu", "province": "Manisa", "district": "Turgutlu", "lat": 38.5, "lon": 27.7084},
    {"name": "Yunusemre", "province": "Manisa", "district": "Yunusemre", "lat": 38.5785, "lon": 27.4270},
    {"name": "Şehzadeler", "province": "Manisa", "district": "Şehzadeler", "lat": 38.6191, "lon": 27.4289},

    # MARDIN
    {"name": "Artuklu", "province": "Mardin", "district": "Artuklu", "lat": 37.3212, "lon": 40.7245},
    {"name": "Dargeçit", "province": "Mardin", "district": "Dargeçit", "lat": 37.5459, "lon": 41.7206},
    {"name": "Derik", "province": "Mardin", "district": "Derik", "lat": 37.3647, "lon": 40.2699},
    {"name": "Kızıltepe", "province": "Mardin", "district": "Kızıltepe", "lat": 37.1917, "lon": 40.5848},
    {"name": "Mazıdağı", "province": "Mardin", "district": "Mazıdağı", "lat": 37.4773, "lon": 40.4865},
    {"name": "Mardin", "province": "Mardin", "district": None, "lat": 37.3212, "lon": 40.7245},
    {"name": "Midyat", "province": "Mardin", "district": "Midyat", "lat": 37.4153, "lon": 41.3733},
    {"name": "Nusaybin", "province": "Mardin", "district": "Nusaybin", "lat": 37.0692, "lon": 41.2165},
    {"name": "Savur", "province": "Mardin", "district": "Savur", "lat": 37.5368, "lon": 40.8874},
    {"name": "Yeşilli", "province": "Mardin", "district": "Yeşilli", "lat": 37.3396, "lon": 40.823},
    {"name": "Ömerli", "province": "Mardin", "district": "Ömerli", "lat": 37.4021, "lon": 40.9539},

    # MERSIN
    {"name": "Anamur", "province": "Mersin", "district": "Anamur", "lat": 36.0803, "lon": 32.8312},
    {"name": "Aydıncık", "province": "Mersin", "district": "Aydıncık", "lat": 36.1452, "lon": 33.3224},
    {"name": "Bozyazı", "province": "Mersin", "district": "Bozyazı", "lat": 36.1048, "lon": 32.9743},
    {"name": "Erdemli", "province": "Mersin", "district": "Erdemli", "lat": 36.6057, "lon": 34.3103},
    {"name": "Gülnar", "province": "Mersin", "district": "Gülnar", "lat": 36.3387, "lon": 33.399},
    {"name": "Mersin", "province": "Mersin", "district": None, "lat": 36.8, "lon": 34.6333},
    {"name": "Mut", "province": "Mersin", "district": "Mut", "lat": 36.6434, "lon": 33.4373},
    {"name": "Silifke", "province": "Mersin", "district": "Silifke", "lat": 36.3778, "lon": 33.926},
    {"name": "Tarsus", "province": "Mersin", "district": "Tarsus", "lat": 36.9165, "lon": 34.8951},
    {"name": "Çamlıyayla", "province": "Mersin", "district": "Çamlıyayla", "lat": 37.1665, "lon": 34.5934},
    {"name": "Akdeniz", "province": "Mersin", "district": "Akdeniz", "lat": 36.7994, "lon": 34.6177},
    {"name": "Mezitli", "province": "Mersin", "district": "Mezitli", "lat": 36.7609, "lon": 34.5246},
    {"name": "Toroslar", "province": "Mersin", "district": "Toroslar", "lat": 36.8452, "lon": 34.5821},
    {"name": "Yenişehir", "province": "Mersin", "district": "Yenişehir", "lat": 36.8114, "lon": 34.5786},

    # MUGLA
    {"name": "Bodrum", "province": "Mugla", "district": "Bodrum", "lat": 37.0344, "lon": 27.4307},
    {"name": "Dalaman", "province": "Mugla", "district": "Dalaman", "lat": 36.7672, "lon": 28.8003},
    {"name": "Datça", "province": "Mugla", "district": "Datça", "lat": 36.7263, "lon": 27.6874},
    {"name": "Fethiye", "province": "Mugla", "district": "Fethiye", "lat": 36.6221, "lon": 29.1153},
    {"name": "Kavaklıdere", "province": "Mugla", "district": "Kavaklıdere", "lat": 37.4456, "lon": 28.3649},
    {"name": "Köyceğiz", "province": "Mugla", "district": "Köyceğiz", "lat": 36.9585, "lon": 28.6889},
    {"name": "Marmaris", "province": "Mugla", "district": "Marmaris", "lat": 36.8523, "lon": 28.2743},
    {"name": "Menteşe", "province": "Mugla", "district": "Menteşe", "lat": 37.2153, "lon": 28.3636},
    {"name": "Mugla", "province": "Mugla", "district": None, "lat": 37.2153, "lon": 28.3636},
    {"name": "Milas", "province": "Mugla", "district": "Milas", "lat": 37.3163, "lon": 27.78},
    {"name": "Ortaca", "province": "Mugla", "district": "Ortaca", "lat": 36.8389, "lon": 28.7655},
    {"name": "Ula", "province": "Mugla", "district": "Ula", "lat": 37.1029, "lon": 28.4164},
    {"name": "Yatağan", "province": "Mugla", "district": "Yatağan", "lat": 37.3417, "lon": 28.1395},
    {"name": "Seydikemer", "province": "Mugla", "district": "Seydikemer", "lat": 36.6328, "lon": 29.3419},

    # MUS
    {"name": "Bulanık", "province": "Mus", "district": "Bulanık", "lat": 39.0924, "lon": 42.2708},
    {"name": "Hasköy", "province": "Mus", "district": "Hasköy", "lat": 38.6826, "lon": 41.6885},
    {"name": "Korkut", "province": "Mus", "district": "Korkut", "lat": 38.7388, "lon": 41.783},
    {"name": "Malazgirt", "province": "Mus", "district": "Malazgirt", "lat": 39.1461, "lon": 42.5409},
    {"name": "Mus", "province": "Mus", "district": None, "lat": 38.7462, "lon": 41.4943},
    {"name": "Varto", "province": "Mus", "district": "Varto", "lat": 39.1721, "lon": 41.4547},

    # NEVSEHIR
    {"name": "Acıgöl", "province": "Nevsehir", "district": "Acıgöl", "lat": 38.5502, "lon": 34.509},
    {"name": "Avanos", "province": "Nevsehir", "district": "Avanos", "lat": 38.8709, "lon": 34.8537},
    {"name": "Derinkuyu", "province": "Nevsehir", "district": "Derinkuyu", "lat": 38.4003, "lon": 34.6996},
    {"name": "Gülşehir", "province": "Nevsehir", "district": "Gülşehir", "lat": 38.7622, "lon": 34.5027},
    {"name": "Hacıbektaş", "province": "Nevsehir", "district": "Hacıbektaş", "lat": 39.0013, "lon": 34.6427},
    {"name": "Kozaklı", "province": "Nevsehir", "district": "Kozaklı", "lat": 39.2111, "lon": 34.7826},
    {"name": "Nevsehir", "province": "Nevsehir", "district": None, "lat": 38.6939, "lon": 34.6857},
    {"name": "Ürgüp", "province": "Nevsehir", "district": "Ürgüp", "lat": 38.6301, "lon": 34.9116},

    # NIGDE
    {"name": "Altunhisar", "province": "Nigde", "district": "Altunhisar", "lat": 37.999, "lon": 34.3715},
    {"name": "Bor", "province": "Nigde", "district": "Bor", "lat": 37.8876, "lon": 34.5625},
    {"name": "Nigde", "province": "Nigde", "district": None, "lat": 37.9667, "lon": 34.6833},
    {"name": "Ulukışla", "province": "Nigde", "district": "Ulukışla", "lat": 37.5457, "lon": 34.4804},
    {"name": "Çamardı", "province": "Nigde", "district": "Çamardı", "lat": 37.8344, "lon": 34.9864},
    {"name": "Çiftlik", "province": "Nigde", "district": "Çiftlik", "lat": 38.175, "lon": 34.4848},

    # ORDU
    {"name": "Akkuş", "province": "Ordu", "district": "Akkuş", "lat": 40.7925, "lon": 37.0177},
    {"name": "Altınordu", "province": "Ordu", "district": "Altınordu", "lat": 40.9862, "lon": 37.8797},
    {"name": "Aybastı", "province": "Ordu", "district": "Aybastı", "lat": 40.6846, "lon": 37.3988},
    {"name": "Fatsa", "province": "Ordu", "district": "Fatsa", "lat": 41.0309, "lon": 37.5002},
    {"name": "Gölköy", "province": "Ordu", "district": "Gölköy", "lat": 40.6873, "lon": 37.6156},
    {"name": "Gülyalı", "province": "Ordu", "district": "Gülyalı", "lat": 40.9663, "lon": 38.0586},
    {"name": "Gürgentepe", "province": "Ordu", "district": "Gürgentepe", "lat": 40.7886, "lon": 37.6009},
    {"name": "Kabadüz", "province": "Ordu", "district": "Kabadüz", "lat": 40.8598, "lon": 37.8908},
    {"name": "Kabataş", "province": "Ordu", "district": "Kabataş", "lat": 40.7524, "lon": 37.4499},
    {"name": "Korgan", "province": "Ordu", "district": "Korgan", "lat": 40.8296, "lon": 37.3441},
    {"name": "Kumru", "province": "Ordu", "district": "Kumru", "lat": 40.872, "lon": 37.2618},
    {"name": "Ordu", "province": "Ordu", "district": None, "lat": 40.9862, "lon": 37.8797},
    {"name": "Mesudiye", "province": "Ordu", "district": "Mesudiye", "lat": 40.4636, "lon": 37.7736},
    {"name": "Perşembe", "province": "Ordu", "district": "Perşembe", "lat": 41.0669, "lon": 37.7736},
    {"name": "Ulubey", "province": "Ordu", "district": "Ulubey", "lat": 40.873, "lon": 37.7585},
    {"name": "Çamaş", "province": "Ordu", "district": "Çamaş", "lat": 40.9026, "lon": 37.5281},
    {"name": "Çaybaşı", "province": "Ordu", "district": "Çaybaşı", "lat": 41.0172, "lon": 37.0987},
    {"name": "Ünye", "province": "Ordu", "district": "Ünye", "lat": 41.1262, "lon": 37.2854},
    {"name": "İkizce", "province": "Ordu", "district": "İkizce", "lat": 41.0544, "lon": 37.0778},

    # OSMANIYE
    {"name": "Bahçe", "province": "Osmaniye", "district": "Bahçe", "lat": 37.1871, "lon": 36.5589},
    {"name": "Düziçi", "province": "Osmaniye", "district": "Düziçi", "lat": 37.2401, "lon": 36.4534},
    {"name": "Hasanbeyli", "province": "Osmaniye", "district": "Hasanbeyli", "lat": 37.1309, "lon": 36.5555},
    {"name": "Kadirli", "province": "Osmaniye", "district": "Kadirli", "lat": 37.4618, "lon": 36.1694},
    {"name": "Osmaniye", "province": "Osmaniye", "district": None, "lat": 37.0742, "lon": 36.2478},
    {"name": "Sumbas", "province": "Osmaniye", "district": "Sumbas", "lat": 37.4536, "lon": 36.0248},
    {"name": "Toprakkale", "province": "Osmaniye", "district": "Toprakkale", "lat": 37.0666, "lon": 36.1456},

    # RIZE
    {"name": "Ardeşen", "province": "Rize", "district": "Ardeşen", "lat": 41.1919, "lon": 40.9894},
    {"name": "Derepazarı", "province": "Rize", "district": "Derepazarı", "lat": 41.0243, "lon": 40.4216},
    {"name": "Fındıklı", "province": "Rize", "district": "Fındıklı", "lat": 41.2712, "lon": 41.1414},
    {"name": "Güneysu", "province": "Rize", "district": "Güneysu", "lat": 40.9772, "lon": 40.6136},
    {"name": "Hemşin", "province": "Rize", "district": "Hemşin", "lat": 41.0475, "lon": 40.8988},
    {"name": "Kalkandere", "province": "Rize", "district": "Kalkandere", "lat": 40.9279, "lon": 40.4425},
    {"name": "Rize", "province": "Rize", "district": None, "lat": 41.0201, "lon": 40.5234},
    {"name": "Pazar", "province": "Rize", "district": "Pazar", "lat": 41.1803, "lon": 40.8868},
    {"name": "Çamlıhemşin", "province": "Rize", "district": "Çamlıhemşin", "lat": 41.0456, "lon": 41.0057},
    {"name": "Çayeli", "province": "Rize", "district": "Çayeli", "lat": 41.0878, "lon": 40.7237},
    {"name": "İkizdere", "province": "Rize", "district": "İkizdere", "lat": 40.778, "lon": 40.5596},
    {"name": "İyidere", "province": "Rize", "district": "İyidere", "lat": 41.012, "lon": 40.361},

    # SAKARYA
    {"name": "Akyazı", "province": "Sakarya", "district": "Akyazı", "lat": 40.6814, "lon": 30.6246},
    {"name": "Ferizli", "province": "Sakarya", "district": "Ferizli", "lat": 40.9402, "lon": 30.4846},
    {"name": "Geyve", "province": "Sakarya", "district": "Geyve", "lat": 40.5091, "lon": 30.2903},
    {"name": "Hendek", "province": "Sakarya", "district": "Hendek", "lat": 40.7955, "lon": 30.7453},
    {"name": "Karapürçek", "province": "Sakarya", "district": "Karapürçek", "lat": 40.6422, "lon": 30.5375},
    {"name": "Karasu", "province": "Sakarya", "district": "Karasu", "lat": 41.0956, "lon": 30.6925},
    {"name": "Kaynarca", "province": "Sakarya", "district": "Kaynarca", "lat": 41.034, "lon": 30.3055},
    {"name": "Kocaali", "province": "Sakarya", "district": "Kocaali", "lat": 41.0543, "lon": 30.8507},
    {"name": "Sakarya", "province": "Sakarya", "district": None, "lat": 40.7731, "lon": 30.4044},
    {"name": "Pamukova", "province": "Sakarya", "district": "Pamukova", "lat": 40.5056, "lon": 30.1693},
    {"name": "Sapanca", "province": "Sakarya", "district": "Sapanca", "lat": 40.6931, "lon": 30.2734},
    {"name": "Söğütlü", "province": "Sakarya", "district": "Söğütlü", "lat": 40.9039, "lon": 30.4717},
    {"name": "Taraklı", "province": "Sakarya", "district": "Taraklı", "lat": 40.3966, "lon": 30.4922},
    {"name": "Adapazarı", "province": "Sakarya", "district": "Adapazarı", "lat": 40.7667, "lon": 30.4000},
    {"name": "Serdivan", "province": "Sakarya", "district": "Serdivan", "lat": 40.7141, "lon": 30.3528},
    {"name": "Erenler", "province": "Sakarya", "district": "Erenler", "lat": 40.7361, "lon": 30.3392},

    # SAMSUN
    {"name": "Alaçam", "province": "Samsun", "district": "Alaçam", "lat": 41.6069, "lon": 35.5973},
    {"name": "Asarcik", "province": "Samsun", "district": "Asarcik", "lat": 41.036, "lon": 36.2348},
    {"name": "Ayvacık", "province": "Samsun", "district": "Ayvacık", "lat": 40.9891, "lon": 36.6305},
    {"name": "Bafra", "province": "Samsun", "district": "Bafra", "lat": 41.5666, "lon": 35.9025},
    {"name": "Havza", "province": "Samsun", "district": "Havza", "lat": 40.9657, "lon": 35.6671},
    {"name": "Kavak", "province": "Samsun", "district": "Kavak", "lat": 41.0685, "lon": 36.0269},
    {"name": "Ladik", "province": "Samsun", "district": "Ladik", "lat": 40.9082, "lon": 35.8946},
    {"name": "Samsun", "province": "Samsun", "district": None, "lat": 41.2867, "lon": 36.33},
    {"name": "Ondokuz Mayıs", "province": "Samsun", "district": "Ondokuz Mayıs", "lat": 41.4957, "lon": 36.0625},
    {"name": "Salıpazarı", "province": "Samsun", "district": "Salıpazarı", "lat": 41.0813, "lon": 36.8258},
    {"name": "Tekkeköy", "province": "Samsun", "district": "Tekkeköy", "lat": 41.2135, "lon": 36.4578},
    {"name": "Terme", "province": "Samsun", "district": "Terme", "lat": 41.209, "lon": 36.9722},
    {"name": "Vezirköprü", "province": "Samsun", "district": "Vezirköprü", "lat": 41.1434, "lon": 35.4605},
    {"name": "Yakakent", "province": "Samsun", "district": "Yakakent", "lat": 41.633, "lon": 35.5316},
    {"name": "Çarşamba", "province": "Samsun", "district": "Çarşamba", "lat": 41.1983, "lon": 36.727},
    {"name": "Atakum", "province": "Samsun", "district": "Atakum", "lat": 41.3314, "lon": 36.2716},
    {"name": "Canik", "province": "Samsun", "district": "Canik", "lat": 41.1978, "lon": 36.2706},
    {"name": "İlkadım", "province": "Samsun", "district": "İlkadım", "lat": 41.2832, "lon": 36.3338},

    # SANLIURFA
    {"name": "Akçakale", "province": "Sanliurfa", "district": "Akçakale", "lat": 36.7083, "lon": 38.9487},
    {"name": "Birecik", "province": "Sanliurfa", "district": "Birecik", "lat": 37.0315, "lon": 37.98},
    {"name": "Bozova", "province": "Sanliurfa", "district": "Bozova", "lat": 37.362, "lon": 38.5254},
    {"name": "Ceylanpınar", "province": "Sanliurfa", "district": "Ceylanpınar", "lat": 36.8442, "lon": 40.0516},
    {"name": "Halfeti", "province": "Sanliurfa", "district": "Halfeti", "lat": 37.2309, "lon": 37.9457},
    {"name": "Harran", "province": "Sanliurfa", "district": "Harran", "lat": 36.871, "lon": 39.0251},
    {"name": "Hilvan", "province": "Sanliurfa", "district": "Hilvan", "lat": 37.5862, "lon": 38.9547},
    {"name": "Sanliurfa", "province": "Sanliurfa", "district": None, "lat": 37.1591, "lon": 38.7969},
    {"name": "Siverek", "province": "Sanliurfa", "district": "Siverek", "lat": 37.7541, "lon": 39.3177},
    {"name": "Suruç", "province": "Sanliurfa", "district": "Suruç", "lat": 36.9752, "lon": 38.4243},
    {"name": "Viranşehir", "province": "Sanliurfa", "district": "Viranşehir", "lat": 37.2329, "lon": 39.762},
    {"name": "Haliliye", "province": "Sanliurfa", "district": "Haliliye", "lat": 37.1654, "lon": 38.7856},
    {"name": "Karaköprü", "province": "Sanliurfa", "district": "Karaköprü", "lat": 37.2019, "lon": 38.7527},
    {"name": "Eyyübiye", "province": "Sanliurfa", "district": "Eyyübiye", "lat": 37.1467, "lon": 38.8063},

    # SIIRT
    {"name": "Aydınlar", "province": "Siirt", "district": "Aydınlar", "lat": 37.9501, "lon": 42.0125},
    {"name": "Baykan", "province": "Siirt", "district": "Baykan", "lat": 38.1629, "lon": 41.7857},
    {"name": "Eruh", "province": "Siirt", "district": "Eruh", "lat": 37.7506, "lon": 42.1808},
    {"name": "Kurtalan", "province": "Siirt", "district": "Kurtalan", "lat": 37.9284, "lon": 41.6974},
    {"name": "Siirt", "province": "Siirt", "district": None, "lat": 37.9333, "lon": 41.95},
    {"name": "Pervari", "province": "Siirt", "district": "Pervari", "lat": 37.9325, "lon": 42.548},
    {"name": "Şirvan", "province": "Siirt", "district": "Şirvan", "lat": 38.0618, "lon": 42.0299},

    # SINOP
    {"name": "Ayancık", "province": "Sinop", "district": "Ayancık", "lat": 41.9461, "lon": 34.5883},
    {"name": "Boyabat", "province": "Sinop", "district": "Boyabat", "lat": 41.469, "lon": 34.7672},
    {"name": "Dikmen", "province": "Sinop", "district": "Dikmen", "lat": 41.6516, "lon": 35.2651},
    {"name": "Durağan", "province": "Sinop", "district": "Durağan", "lat": 41.418, "lon": 35.0558},
    {"name": "Erfelek", "province": "Sinop", "district": "Erfelek", "lat": 41.8794, "lon": 34.9081},
    {"name": "Gerze", "province": "Sinop", "district": "Gerze", "lat": 41.8033, "lon": 35.1996},
    {"name": "Sinop", "province": "Sinop", "district": None, "lat": 42.0231, "lon": 35.1531},
    {"name": "Saraydüzü", "province": "Sinop", "district": "Saraydüzü", "lat": 41.3295, "lon": 34.8486},
    {"name": "Türkeli", "province": "Sinop", "district": "Türkeli", "lat": 41.9483, "lon": 34.3396},

    # SIRNAK
    {"name": "Beytüşşebap", "province": "Sirnak", "district": "Beytüşşebap", "lat": 37.5709, "lon": 43.1702},
    {"name": "Cizre", "province": "Sirnak", "district": "Cizre", "lat": 37.3324, "lon": 42.1855},
    {"name": "Güçlükonak", "province": "Sirnak", "district": "Güçlükonak", "lat": 37.4712, "lon": 41.9111},
    {"name": "Sirnak", "province": "Sirnak", "district": None, "lat": 37.5164, "lon": 42.4611},
    {"name": "Silopi", "province": "Sirnak", "district": "Silopi", "lat": 37.2492, "lon": 42.4708},
    {"name": "Uludere", "province": "Sirnak", "district": "Uludere", "lat": 37.4467, "lon": 42.8514},
    {"name": "İdil", "province": "Sirnak", "district": "İdil", "lat": 37.3402, "lon": 41.8924},

    # SIVAS
    {"name": "Akıncılar", "province": "Sivas", "district": "Akıncılar", "lat": 40.0787, "lon": 38.3468},
    {"name": "Altınyayla", "province": "Sivas", "district": "Altınyayla", "lat": 39.2717, "lon": 36.7515},
    {"name": "Divriği", "province": "Sivas", "district": "Divriği", "lat": 39.3687, "lon": 38.1138},
    {"name": "Doğanşar", "province": "Sivas", "district": "Doğanşar", "lat": 40.2142, "lon": 37.5365},
    {"name": "Gemerek", "province": "Sivas", "district": "Gemerek", "lat": 39.1831, "lon": 36.0711},
    {"name": "Gölova", "province": "Sivas", "district": "Gölova", "lat": 40.0613, "lon": 38.6084},
    {"name": "Gürün", "province": "Sivas", "district": "Gürün", "lat": 38.799, "lon": 37.1572},
    {"name": "Hafik", "province": "Sivas", "district": "Hafik", "lat": 39.8546, "lon": 37.389},
    {"name": "Kangal", "province": "Sivas", "district": "Kangal", "lat": 39.276, "lon": 37.4509},
    {"name": "Koyulhisar", "province": "Sivas", "district": "Koyulhisar", "lat": 40.3013, "lon": 37.8323},
    {"name": "Sivas", "province": "Sivas", "district": None, "lat": 39.7477, "lon": 37.0179},
    {"name": "Suşehri", "province": "Sivas", "district": "Suşehri", "lat": 40.1627, "lon": 38.0856},
    {"name": "Ulaş", "province": "Sivas", "district": "Ulaş", "lat": 39.4432, "lon": 37.0354},
    {"name": "Yıldızeli", "province": "Sivas", "district": "Yıldızeli", "lat": 39.8672, "lon": 36.5933},
    {"name": "Zara", "province": "Sivas", "district": "Zara", "lat": 39.8972, "lon": 37.7591},
    {"name": "İmranlı", "province": "Sivas", "district": "İmranlı", "lat": 39.876, "lon": 38.1129},
    {"name": "Şarkışla", "province": "Sivas", "district": "Şarkışla", "lat": 39.3641, "lon": 36.4032},

    # TEKIRDAG
    {"name": "Hayrabolu", "province": "Tekirdag", "district": "Hayrabolu", "lat": 41.2147, "lon": 27.1082},
    {"name": "Malkara", "province": "Tekirdag", "district": "Malkara", "lat": 40.8931, "lon": 26.9024},
    {"name": "Marmaraereğlisi", "province": "Tekirdag", "district": "Marmaraereğlisi", "lat": 40.9694, "lon": 27.955},
    {"name": "Tekirdag", "province": "Tekirdag", "district": None, "lat": 40.9833, "lon": 27.5167},
    {"name": "Muratlı", "province": "Tekirdag", "district": "Muratlı", "lat": 41.1723, "lon": 27.5015},
    {"name": "Saray", "province": "Tekirdag", "district": "Saray", "lat": 41.4427, "lon": 27.9214},
    {"name": "Süleymanpaşa", "province": "Tekirdag", "district": "Süleymanpaşa", "lat": 40.9833, "lon": 27.5167},
    {"name": "Çerkezköy", "province": "Tekirdag", "district": "Çerkezköy", "lat": 41.2862, "lon": 27.9995},
    {"name": "Çorlu", "province": "Tekirdag", "district": "Çorlu", "lat": 41.1591, "lon": 27.8041},
    {"name": "Şarköy", "province": "Tekirdag", "district": "Şarköy", "lat": 40.6149, "lon": 27.1122},
    {"name": "Kapaklı", "province": "Tekirdag", "district": "Kapaklı", "lat": 41.3280, "lon": 28.0235},
    {"name": "Ergene", "province": "Tekirdag", "district": "Ergene", "lat": 41.2739, "lon": 27.8953},

    # TOKAT
    {"name": "Almus", "province": "Tokat", "district": "Almus", "lat": 40.375, "lon": 36.9037},
    {"name": "Artova", "province": "Tokat", "district": "Artova", "lat": 40.1141, "lon": 36.3008},
    {"name": "Başçiftlik", "province": "Tokat", "district": "Başçiftlik", "lat": 40.5469, "lon": 37.1683},
    {"name": "Erbaa", "province": "Tokat", "district": "Erbaa", "lat": 40.6728, "lon": 36.5715},
    {"name": "Tokat", "province": "Tokat", "district": None, "lat": 40.3167, "lon": 36.55},
    {"name": "Niksar", "province": "Tokat", "district": "Niksar", "lat": 40.5913, "lon": 36.9435},
    {"name": "Pazar", "province": "Tokat", "district": "Pazar", "lat": 40.2758, "lon": 36.2823},
    {"name": "Reşadiye", "province": "Tokat", "district": "Reşadiye", "lat": 40.4297, "lon": 37.3744},
    {"name": "Sulusaray", "province": "Tokat", "district": "Sulusaray", "lat": 39.9975, "lon": 36.0836},
    {"name": "Turhal", "province": "Tokat", "district": "Turhal", "lat": 40.3896, "lon": 36.078},
    {"name": "Yeşilyurt", "province": "Tokat", "district": "Yeşilyurt", "lat": 40.0074, "lon": 36.2167},
    {"name": "Zile", "province": "Tokat", "district": "Zile", "lat": 40.2815, "lon": 35.9314},

    # TRABZON
    {"name": "Akçaabat", "province": "Trabzon", "district": "Akçaabat", "lat": 41.0216, "lon": 39.5707},
    {"name": "Araklı", "province": "Trabzon", "district": "Araklı", "lat": 40.9358, "lon": 40.058},
    {"name": "Arsin", "province": "Trabzon", "district": "Arsin", "lat": 40.9537, "lon": 39.9326},
    {"name": "Beşikdüzü", "province": "Trabzon", "district": "Beşikdüzü", "lat": 41.0527, "lon": 39.228},
    {"name": "Dernekpazarı", "province": "Trabzon", "district": "Dernekpazarı", "lat": 40.7996, "lon": 40.2479},
    {"name": "Düzköy", "province": "Trabzon", "district": "Düzköy", "lat": 40.8738, "lon": 39.4261},
    {"name": "Hayrat", "province": "Trabzon", "district": "Hayrat", "lat": 40.8892, "lon": 40.368},
    {"name": "Köprübaşı", "province": "Trabzon", "district": "Köprübaşı", "lat": 40.8072, "lon": 40.1242},
    {"name": "Maçka", "province": "Trabzon", "district": "Maçka", "lat": 40.812, "lon": 39.6127},
    {"name": "Trabzon", "province": "Trabzon", "district": None, "lat": 41.0015, "lon": 39.7178},
    {"name": "Of", "province": "Trabzon", "district": "Of", "lat": 40.9476, "lon": 40.2694},
    {"name": "Sürmene", "province": "Trabzon", "district": "Sürmene", "lat": 40.9128, "lon": 40.1135},
    {"name": "Tonya", "province": "Trabzon", "district": "Tonya", "lat": 40.8863, "lon": 39.2908},
    {"name": "Vakfıkebir", "province": "Trabzon", "district": "Vakfıkebir", "lat": 41.0472, "lon": 39.2762},
    {"name": "Yomra", "province": "Trabzon", "district": "Yomra", "lat": 40.9592, "lon": 39.8471},
    {"name": "Çarşıbaşı", "province": "Trabzon", "district": "Çarşıbaşı", "lat": 41.0826, "lon": 39.3785},
    {"name": "Çaykara", "province": "Trabzon", "district": "Çaykara", "lat": 40.7479, "lon": 40.242},
    {"name": "Şalpazarı", "province": "Trabzon", "district": "Şalpazarı", "lat": 40.9418, "lon": 39.1938},
    {"name": "Ortahisar", "province": "Trabzon", "district": "Ortahisar", "lat": 41.0027, "lon": 39.7168},
    {"name": "Akçaabat", "province": "Trabzon", "district": "Akçaabat", "lat": 41.0186, "lon": 39.5627},

    # TUNCELI
    {"name": "Hozat", "province": "Tunceli", "district": "Hozat", "lat": 39.1076, "lon": 39.2194},
    {"name": "Mazgirt", "province": "Tunceli", "district": "Mazgirt", "lat": 39.0195, "lon": 39.6059},
    {"name": "Tunceli", "province": "Tunceli", "district": None, "lat": 39.1079, "lon": 39.548},
    {"name": "Nazımiye", "province": "Tunceli", "district": "Nazımiye", "lat": 39.1796, "lon": 39.8288},
    {"name": "Ovacık", "province": "Tunceli", "district": "Ovacık", "lat": 39.3584, "lon": 39.2144},
    {"name": "Pertek", "province": "Tunceli", "district": "Pertek", "lat": 38.8656, "lon": 39.3277},
    {"name": "Pülümür", "province": "Tunceli", "district": "Pülümür", "lat": 39.4876, "lon": 39.8991},
    {"name": "Çemişgezek", "province": "Tunceli", "district": "Çemişgezek", "lat": 39.0629, "lon": 38.9104},

    # USAK
    {"name": "Banaz", "province": "Usak", "district": "Banaz", "lat": 38.74, "lon": 29.7532},
    {"name": "Eşme", "province": "Usak", "district": "Eşme", "lat": 38.3999, "lon": 28.967},
    {"name": "Karahallı", "province": "Usak", "district": "Karahallı", "lat": 38.3206, "lon": 29.5313},
    {"name": "Usak", "province": "Usak", "district": None, "lat": 38.6823, "lon": 29.4082},
    {"name": "Sivaslı", "province": "Usak", "district": "Sivaslı", "lat": 38.5, "lon": 29.684},
    {"name": "Ulubey", "province": "Usak", "district": "Ulubey", "lat": 38.4193, "lon": 29.2909},

    # VAN
    {"name": "Bahçesaray", "province": "Van", "district": "Bahçesaray", "lat": 38.1237, "lon": 42.8077},
    {"name": "Başkale", "province": "Van", "district": "Başkale", "lat": 38.0449, "lon": 44.0163},
    {"name": "Edremit", "province": "Van", "district": "Edremit", "lat": 38.4258, "lon": 43.2602},
    {"name": "Erciş", "province": "Van", "district": "Erciş", "lat": 39.029, "lon": 43.3591},
    {"name": "Gevaş", "province": "Van", "district": "Gevaş", "lat": 38.2953, "lon": 43.1083},
    {"name": "Gürpınar", "province": "Van", "district": "Gürpınar", "lat": 38.3233, "lon": 43.4079},
    {"name": "Van", "province": "Van", "district": None, "lat": 38.4891, "lon": 43.4089},
    {"name": "Muradiye", "province": "Van", "district": "Muradiye", "lat": 38.9903, "lon": 43.7612},
    {"name": "Saray", "province": "Van", "district": "Saray", "lat": 38.6494, "lon": 44.1695},
    {"name": "Çaldıran", "province": "Van", "district": "Çaldıran", "lat": 39.1355, "lon": 43.9029},
    {"name": "Çatak", "province": "Van", "district": "Çatak", "lat": 38.0069, "lon": 43.0592},
    {"name": "Özalp", "province": "Van", "district": "Özalp", "lat": 38.6534, "lon": 43.9897},
    {"name": "Tuşba", "province": "Van", "district": "Tuşba", "lat": 38.5481, "lon": 43.3811},
    {"name": "İpekyolu", "province": "Van", "district": "İpekyolu", "lat": 38.5040, "lon": 43.3772},

    # YALOVA
    {"name": "Altınova", "province": "Yalova", "district": "Altınova", "lat": 40.6963, "lon": 29.5099},
    {"name": "Armutlu", "province": "Yalova", "district": "Armutlu", "lat": 40.5196, "lon": 28.828},
    {"name": "Yalova", "province": "Yalova", "district": None, "lat": 40.65, "lon": 29.2667},
    {"name": "Termal", "province": "Yalova", "district": "Termal", "lat": 40.6062, "lon": 29.1743},
    {"name": "Çiftlikköy", "province": "Yalova", "district": "Çiftlikköy", "lat": 40.6645, "lon": 29.3229},
    {"name": "Çınarcık", "province": "Yalova", "district": "Çınarcık", "lat": 40.6434, "lon": 29.1193},

    # YOZGAT
    {"name": "Akdağmadeni", "province": "Yozgat", "district": "Akdağmadeni", "lat": 39.7821, "lon": 35.8921},
    {"name": "Aydıncık", "province": "Yozgat", "district": "Aydıncık", "lat": 40.1303, "lon": 35.2852},
    {"name": "Boğazlıyan", "province": "Yozgat", "district": "Boğazlıyan", "lat": 39.1913, "lon": 35.2463},
    {"name": "Kadışehri", "province": "Yozgat", "district": "Kadışehri", "lat": 39.9975, "lon": 35.7918},
    {"name": "Yozgat", "province": "Yozgat", "district": None, "lat": 39.8181, "lon": 34.8147},
    {"name": "Saraykent", "province": "Yozgat", "district": "Saraykent", "lat": 39.6937, "lon": 35.5102},
    {"name": "Sarıkaya", "province": "Yozgat", "district": "Sarıkaya", "lat": 39.4936, "lon": 35.3755},
    {"name": "Sorgun", "province": "Yozgat", "district": "Sorgun", "lat": 39.8099, "lon": 35.1854},
    {"name": "Yenifakılı", "province": "Yozgat", "district": "Yenifakılı", "lat": 39.2128, "lon": 35.0024},
    {"name": "Yerköy", "province": "Yozgat", "district": "Yerköy", "lat": 39.6871, "lon": 34.4657},
    {"name": "Çandır", "province": "Yozgat", "district": "Çandır", "lat": 39.2446, "lon": 35.5139},
    {"name": "Çayıralan", "province": "Yozgat", "district": "Çayıralan", "lat": 39.3048, "lon": 35.6464},
    {"name": "Çekerek", "province": "Yozgat", "district": "Çekerek", "lat": 40.065, "lon": 35.5073},
    {"name": "Şefaatli", "province": "Yozgat", "district": "Şefaatli", "lat": 39.4985, "lon": 34.7497},

    # ZINGULDAK
    {"name": "Alaplı", "province": "Zonguldak", "district": "Alaplı", "lat": 41.1804, "lon": 31.3862},
    {"name": "Devrek", "province": "Zonguldak", "district": "Devrek", "lat": 41.2189, "lon": 31.9558},
    {"name": "Ereğli", "province": "Zonguldak", "district": "Ereğli", "lat": 41.2831, "lon": 31.4266},
    {"name": "Gökçebey", "province": "Zonguldak", "district": "Gökçebey", "lat": 41.3067, "lon": 32.1385},
    {"name": "Zonguldak", "province": "Zonguldak", "district": None, "lat": 41.4564, "lon": 31.7987},
    {"name": "Çaycuma", "province": "Zonguldak", "district": "Çaycuma", "lat": 41.4269, "lon": 32.0728},
    {"name": "Kilimli", "province": "Zonguldak", "district": "Kilimli", "lat": 41.4866, "lon": 31.7365},
    {"name": "Kozlu", "province": "Zonguldak", "district": "Kozlu", "lat": 41.4401, "lon": 31.7643},

    # ÇANAKKALE
    {"name": "Ayvacık", "province": "Çanakkale", "district": "Ayvacık", "lat": 39.6012, "lon": 26.4031},
    {"name": "Bayramiç", "province": "Çanakkale", "district": "Bayramiç", "lat": 39.8086, "lon": 26.613},
    {"name": "Biga", "province": "Çanakkale", "district": "Biga", "lat": 40.227, "lon": 27.2428},
    {"name": "Bozcaada", "province": "Çanakkale", "district": "Bozcaada", "lat": 39.8347, "lon": 26.0702},
    {"name": "Eceabat", "province": "Çanakkale", "district": "Eceabat", "lat": 40.1852, "lon": 26.3591},
    {"name": "Ezine", "province": "Çanakkale", "district": "Ezine", "lat": 39.7857, "lon": 26.3434},
    {"name": "Gelibolu", "province": "Çanakkale", "district": "Gelibolu", "lat": 40.4054, "lon": 26.6723},
    {"name": "Gökçeada", "province": "Çanakkale", "district": "Gökçeada", "lat": 40.2004, "lon": 25.9085},
    {"name": "Lapseki", "province": "Çanakkale", "district": "Lapseki", "lat": 40.3444, "lon": 26.6846},
    {"name": "Çanakkale", "province": "Çanakkale", "district": None, "lat": 40.1553, "lon": 26.4142},
    {"name": "Yenice", "province": "Çanakkale", "district": "Yenice", "lat": 39.9298, "lon": 27.2555},
    {"name": "Çan", "province": "Çanakkale", "district": "Çan", "lat": 40.0289, "lon": 27.0512},

    # ÇANKIRI
    {"name": "Atkaracalar", "province": "Çankiri", "district": "Atkaracalar", "lat": 40.7981, "lon": 33.083},
    {"name": "Bayramören", "province": "Çankiri", "district": "Bayramören", "lat": 40.9431, "lon": 33.204},
    {"name": "Eldivan", "province": "Çankiri", "district": "Eldivan", "lat": 40.5307, "lon": 33.4966},
    {"name": "Ilgaz", "province": "Çankiri", "district": "Ilgaz", "lat": 40.9249, "lon": 33.6253},
    {"name": "Korgun", "province": "Çankiri", "district": "Korgun", "lat": 40.7348, "lon": 33.5185},
    {"name": "Kurşunlu", "province": "Çankiri", "district": "Kurşunlu", "lat": 40.8407, "lon": 33.2613},
    {"name": "Kızılırmak", "province": "Çankiri", "district": "Kızılırmak", "lat": 40.346, "lon": 33.9872},
    {"name": "Çankiri", "province": "Çankiri", "district": None, "lat": 40.6013, "lon": 33.6134},
    {"name": "Orta", "province": "Çankiri", "district": "Orta", "lat": 40.627, "lon": 33.1077},
    {"name": "Yapraklı", "province": "Çankiri", "district": "Yapraklı", "lat": 40.7571, "lon": 33.7788},
    {"name": "Çerkeş", "province": "Çankiri", "district": "Çerkeş", "lat": 40.8114, "lon": 32.8844},
    {"name": "Şabanözü", "province": "Çankiri", "district": "Şabanözü", "lat": 40.4832, "lon": 33.2826},

    # ÇORUM
    {"name": "Alaca", "province": "Çorum", "district": "Alaca", "lat": 40.169, "lon": 34.8415},
    {"name": "Bayat", "province": "Çorum", "district": "Bayat", "lat": 40.579, "lon": 34.9265},
    {"name": "Boğazkale", "province": "Çorum", "district": "Boğazkale", "lat": 40.0215, "lon": 34.6092},
    {"name": "Dodurga", "province": "Çorum", "district": "Dodurga", "lat": 40.8553, "lon": 34.8103},
    {"name": "Kargı", "province": "Çorum", "district": "Kargı", "lat": 41.1327, "lon": 34.4912},
    {"name": "Laçin", "province": "Çorum", "district": "Laçin", "lat": 40.7738, "lon": 34.8844},
    {"name": "Mecitözü", "province": "Çorum", "district": "Mecitözü", "lat": 40.5206, "lon": 35.2953},
    {"name": "Çorum", "province": "Çorum", "district": None, "lat": 40.5506, "lon": 34.9556},
    {"name": "Ortaköy", "province": "Çorum", "district": "Ortaköy", "lat": 40.3517, "lon": 34.4029},
    {"name": "Osmancık", "province": "Çorum", "district": "Osmancık", "lat": 40.9715, "lon": 34.801},
    {"name": "Oğuzlar", "province": "Çorum", "district": "Oğuzlar", "lat": 40.7534, "lon": 34.7043},
    {"name": "Sungurlu", "province": "Çorum", "district": "Sungurlu", "lat": 40.1638, "lon": 34.3753},
    {"name": "Uğurludağ", "province": "Çorum", "district": "Uğurludağ", "lat": 40.4463, "lon": 34.4525},
    {"name": "İskilip", "province": "Çorum", "district": "İskilip", "lat": 40.7307, "lon": 34.471},
]


# ── Konum Kodu Sistemi ────────────────────────────────────────────────────────
# Her il ve ilçeye Türkiye plaka numarası + sıra numarası atanır.
#   01000 = Adana (il merkezi)   01001..N = Adana ilçeleri (alfabetik sıra)
#   34000 = İstanbul merkezi     34001..N = İstanbul ilçeleri
# Plaka numaraları sabit (devlet standardı); yeni ilçe eklenince sadece
# o ilin sıralaması değişir, diğer iller etkilenmez.

# DB'deki province adı (constants.py'daki "province" alanı) → plaka numarası
_PROVINCE_DB_CODES: Dict[str, int] = {
    "Adana": 1,   "Adiyaman": 2,  "Afyon": 3,    "Agri": 4,
    "Amasya": 5,  "Ankara": 6,    "Antalya": 7,   "Artvin": 8,
    "Aydin": 9,   "Balikesir": 10, "Bilecik": 11, "Bingöl": 12,
    "Bitlis": 13, "Bolu": 14,     "Burdur": 15,   "Bursa": 16,
    "Çanakkale": 17, "Çankiri": 18, "Çorum": 19,  "Denizli": 20,
    "Diyarbakir": 21, "Edirne": 22, "Elazığ": 23, "Erzincan": 24,
    "Erzurum": 25, "Eskisehir": 26, "Gaziantep": 27, "Giresun": 28,
    "Gümüşhane": 29, "Hakkari": 30, "Hatay": 31, "Isparta": 32,
    "Mersin": 33, "Istanbul": 34, "Izmir": 35,   "Kars": 36,
    "Kastamonu": 37, "Kayseri": 38, "Kirklareli": 39, "Kirsehir": 40,
    "Kocaeli": 41, "Konya": 42,   "Kütahya": 43, "Malatya": 44,
    "Manisa": 45, "K. Maras": 46, "Mardin": 47,  "Mugla": 48,
    "Mus": 49,    "Nevsehir": 50, "Nigde": 51,   "Ordu": 52,
    "Rize": 53,   "Sakarya": 54,  "Samsun": 55,  "Siirt": 56,
    "Sinop": 57,  "Sivas": 58,    "Tekirdag": 59, "Tokat": 60,
    "Trabzon": 61, "Tunceli": 62, "Sanliurfa": 63, "Usak": 64,
    "Van": 65,    "Yozgat": 66,   "Zonguldak": 67, "Aksaray": 68,
    "Bayburt": 69, "Karaman": 70, "Kırıkkale": 71, "Batman": 72,
    "Sirnak": 73, "Bartın": 74,   "Ardahan": 75,  "Iğdır": 76,
    "Yalova": 77, "Karabük": 78,  "Kilis": 79,   "Osmaniye": 80,
    "Düzce": 81,
}

# GeoJSON NAME_1 (Türkçe resmi il adı) → plaka kodu string (JS/frontend için)
PROVINCE_GEO_TO_CODE: Dict[str, str] = {
    "Adana": "01",      "Adıyaman": "02",   "Afyonkarahisar": "03", "Ağrı": "04",
    "Amasya": "05",     "Ankara": "06",     "Antalya": "07",        "Artvin": "08",
    "Aydın": "09",      "Balıkesir": "10",  "Bilecik": "11",        "Bingöl": "12",
    "Bitlis": "13",     "Bolu": "14",       "Burdur": "15",         "Bursa": "16",
    "Çanakkale": "17",  "Çankırı": "18",    "Çorum": "19",          "Denizli": "20",
    "Diyarbakır": "21", "Edirne": "22",     "Elazığ": "23",         "Erzincan": "24",
    "Erzurum": "25",    "Eskişehir": "26",  "Gaziantep": "27",      "Giresun": "28",
    "Gümüşhane": "29",  "Hakkâri": "30",    "Hatay": "31",          "Isparta": "32",
    "Mersin": "33",     "İstanbul": "34",   "İzmir": "35",          "Kars": "36",
    "Kastamonu": "37",  "Kayseri": "38",    "Kırklareli": "39",     "Kırşehir": "40",
    "Kocaeli": "41",    "Konya": "42",      "Kütahya": "43",        "Malatya": "44",
    "Manisa": "45",     "Kahramanmaraş": "46", "Mardin": "47",      "Muğla": "48",
    "Muş": "49",        "Nevşehir": "50",   "Niğde": "51",          "Ordu": "52",
    "Rize": "53",       "Sakarya": "54",    "Samsun": "55",         "Siirt": "56",
    "Sinop": "57",      "Sivas": "58",      "Tekirdağ": "59",       "Tokat": "60",
    "Trabzon": "61",    "Tunceli": "62",    "Şanlıurfa": "63",      "Uşak": "64",
    "Van": "65",        "Yozgat": "66",     "Zonguldak": "67",      "Aksaray": "68",
    "Bayburt": "69",    "Karaman": "70",    "Kırıkkale": "71",      "Batman": "72",
    "Şırnak": "73",     "Bartın": "74",     "Ardahan": "75",        "Iğdır": "76",
    "Yalova": "77",     "Karabük": "78",    "Kilis": "79",          "Osmaniye": "80",
    "Düzce": "81",
}


def _compute_location_codes() -> None:
    """TURKEY_CITIES her girişine 'code' alanı atar (modül yüklenirken çalışır).

    Format: {plaka:02d}{sıra:03d}
      - İl merkezi: 01000, 06000, 34000 ...
      - İlçeler:    01001..N, 06001..N, 34001..N ... (alfabetik sıra)

    NOT: Girişte zaten "code" alanı varsa dokunulmaz.
    Bu, DB'deki mevcut kodları bozmadan yeni ilçe eklemeyi sağlar.
    """
    from collections import defaultdict

    # Zaten code'u olan ilçeleri topla (sabit kod atanmış)
    pre_assigned: Dict[tuple, str] = {}
    for city in TURKEY_CITIES:
        if city.get("code") and city.get("district"):
            pre_assigned[(city["province"], city["district"])] = city["code"]

    # Sadece code'u olmayan ilçeler için alfabetik sıralama yap
    province_districts: Dict[str, List[str]] = defaultdict(list)
    for city in TURKEY_CITIES:
        if city.get("district") and city["province"] in _PROVINCE_DB_CODES:
            if (city["province"], city["district"]) not in pre_assigned:
                province_districts[city["province"]].append(city["district"])

    district_code_map: Dict[tuple, str] = {}
    for prov, districts in province_districts.items():
        plate = _PROVINCE_DB_CODES[prov]
        for idx, dist in enumerate(sorted(districts), start=1):
            district_code_map[(prov, dist)] = f"{plate:02d}{idx:03d}"

    for city in TURKEY_CITIES:
        if city.get("code"):
            continue  # Zaten atanmış — dokunma
        prov = city["province"]
        dist = city.get("district")
        plate = _PROVINCE_DB_CODES.get(prov)
        if plate is None:
            city["code"] = None
            continue
        city["code"] = f"{plate:02d}000" if dist is None else district_code_map.get((prov, dist))


_compute_location_codes()

# Hızlı reverse lookup: location_code → TURKEY_CITIES girişi
LOCATION_CODE_MAP: Dict[str, Any] = {
    city["code"]: city
    for city in TURKEY_CITIES
    if city.get("code")
}

# GeoJSON ilçe adı → Backend ilçe adı eşleme tablosu
# GeoJSON dosyalarında farklı yazılan ilçe adlarını backend'deki TURKEY_CITIES karşılıklarına çevirir
DISTRICT_NAME_MAP: Dict[str, str] = {
    "19 Mayıs": "Ondokuz Mayıs",
    "19 MAYIS": "Ondokuz Mayıs",
}


def get_location_by_name(name: str) -> Optional[Dict[str, Any]]:
    """Isime gore sehir/ilce bul (buyuk/kucuk harf duyarsiz)."""
    if not name:
        return None
    name_lower = name.strip().lower()
    for city in TURKEY_CITIES:
        if city["name"].lower() == name_lower:
            return city
        if city["province"].lower() == name_lower:
            return city
    return None


# ─── Coğrafi Bölge Tanımları ─────────────────────────────────────────────────
# Tek kaynak: reports.py ve weather.py bu sözlükleri buradan import eder.

REGION_CITIES: Dict[str, List[str]] = {
    "marmara": [
        "İstanbul", "Edirne", "Kırklareli", "Tekirdağ", "Kocaeli",
        "Sakarya", "Yalova", "Balıkesir", "Bursa", "Çanakkale", "Bilecik",
    ],
    "ege": [
        "İzmir", "Manisa", "Aydın", "Muğla", "Denizli", "Uşak", "Kütahya", "Afyonkarahisar",
    ],
    "akdeniz": [
        "Antalya", "Mersin", "Adana", "Hatay", "Osmaniye", "Isparta", "Burdur", "Kahramanmaraş",
    ],
    "iç anadolu": [
        "Ankara", "Eskişehir", "Konya", "Kayseri", "Sivas", "Aksaray",
        "Karaman", "Kırıkkale", "Kırşehir", "Niğde", "Nevşehir", "Yozgat", "Çankırı",
    ],
    "karadeniz": [
        "Trabzon", "Rize", "Artvin", "Giresun", "Ordu", "Samsun", "Sinop",
        "Gümüşhane", "Bayburt", "Tokat", "Amasya", "Çorum", "Bolu",
        "Kastamonu", "Bartın", "Zonguldak", "Düzce", "Karabük",
    ],
    "doğu anadolu": [
        "Erzurum", "Erzincan", "Kars", "Ağrı", "Iğdır", "Van", "Muş",
        "Bitlis", "Hakkari", "Tunceli", "Bingöl", "Malatya", "Elazığ", "Ardahan",
    ],
    "güneydoğu anadolu": [
        "Gaziantep", "Şanlıurfa", "Diyarbakır", "Mardin", "Batman",
        "Siirt", "Şırnak", "Adıyaman", "Kilis",
    ],
}

# Hızlı arama: il_adı (casefold) → bölge_adı
CITY_TO_REGION: Dict[str, str] = {
    city.casefold(): region
    for region, cities in REGION_CITIES.items()
    for city in cities
}

# Bölge adı takma adları (yazım varyantları → normalize)
REGION_ALIASES: Dict[str, str] = {
    "ic anadolu": "iç anadolu",
    "iç anadolu bölgesi": "iç anadolu",
    "dogu anadolu": "doğu anadolu",
    "güneydogu anadolu": "güneydoğu anadolu",
    "guneydogu anadolu": "güneydoğu anadolu",
    "karadeniz bölgesi": "karadeniz",
    "ege bölgesi": "ege",
    "akdeniz bölgesi": "akdeniz",
    "marmara bölgesi": "marmara",
}
