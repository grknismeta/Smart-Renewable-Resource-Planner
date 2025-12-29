"""
Türkiye'nin 81 İli ve Önemli İlçeleri - Koordinatlar ve Bilgiler
Her il için il merkezi (district=None) + önemli/büyük ilçeler dahil edilmiştir.
"""

TURKEY_CITIES = [
    # ADANA
    {"name": "Adana", "district": None, "lat": 37.0, "lon": 35.3213},
    {"name": "Adana", "district": "Ceyhan", "lat": 37.0297, "lon": 35.8169},
    {"name": "Adana", "district": "Kozan", "lat": 37.4514, "lon": 35.8169},
    {"name": "Adana", "district": "Yumurtalık", "lat": 36.7667, "lon": 35.7833},
    
    # ADIYAMAN
    {"name": "Adıyaman", "district": None, "lat": 37.7648, "lon": 38.2786},
    {"name": "Adıyaman", "district": "Kahta", "lat": 37.7833, "lon": 38.6167},
    {"name": "Adıyaman", "district": "Besni", "lat": 37.6933, "lon": 37.8556},
    
    # AFYONKARAHİSAR
    {"name": "Afyonkarahisar", "district": None, "lat": 38.7507, "lon": 30.5567},
    {"name": "Afyonkarahisar", "district": "Sandıklı", "lat": 38.4667, "lon": 30.2667},
    {"name": "Afyonkarahisar", "district": "Dinar", "lat": 38.0667, "lon": 30.1667},
    {"name": "Afyonkarahisar", "district": "Bolvadin", "lat": 38.7167, "lon": 31.05},
    
    # AĞRI
    {"name": "Ağrı", "district": None, "lat": 39.7191, "lon": 43.0503},
    {"name": "Ağrı", "district": "Doğubayazıt", "lat": 39.5475, "lon": 44.0833},
    {"name": "Ağrı", "district": "Patnos", "lat": 39.2333, "lon": 42.8667},
    
    # AMASYA
    {"name": "Amasya", "district": None, "lat": 40.6499, "lon": 35.8353},
    {"name": "Amasya", "district": "Merzifon", "lat": 40.8667, "lon": 35.4667},
    {"name": "Amasya", "district": "Suluova", "lat": 40.8333, "lon": 35.65},
    
    # ANKARA
    {"name": "Ankara", "district": None, "lat": 39.9334, "lon": 32.8597},
    {"name": "Ankara", "district": "Polatlı", "lat": 39.5833, "lon": 32.15},
    {"name": "Ankara", "district": "Çubuk", "lat": 40.2333, "lon": 33.0333},
    {"name": "Ankara", "district": "Beypazarı", "lat": 40.1667, "lon": 31.9167},
    {"name": "Ankara", "district": "Şereflikoçhisar", "lat": 38.9333, "lon": 33.5333},
    
    # ANTALYA
    {"name": "Antalya", "district": None, "lat": 36.8969, "lon": 30.7133},
    {"name": "Antalya", "district": "Alanya", "lat": 36.5444, "lon": 31.9956},
    {"name": "Antalya", "district": "Manavgat", "lat": 36.7878, "lon": 31.4442},
    {"name": "Antalya", "district": "Kumluca", "lat": 36.3667, "lon": 30.2833},
    {"name": "Antalya", "district": "Serik", "lat": 36.9167, "lon": 31.1},
    {"name": "Antalya", "district": "Kaş", "lat": 36.2019, "lon": 29.6414},
    
    # ARTVİN
    {"name": "Artvin", "district": None, "lat": 41.1828, "lon": 41.8183},
    {"name": "Artvin", "district": "Hopa", "lat": 41.4, "lon": 41.4167},
    {"name": "Artvin", "district": "Arhavi", "lat": 41.35, "lon": 41.3},
    
    # AYDIN
    {"name": "Aydın", "district": None, "lat": 37.8560, "lon": 27.8416},
    {"name": "Aydın", "district": "Nazilli", "lat": 37.9167, "lon": 28.3167},
    {"name": "Aydın", "district": "Söke", "lat": 37.75, "lon": 27.4167},
    {"name": "Aydın", "district": "Kuşadası", "lat": 37.8594, "lon": 27.2639},
    {"name": "Aydın", "district": "Didim", "lat": 37.3667, "lon": 27.2667},
    
    # BALIKESİR
    {"name": "Balıkesir", "district": None, "lat": 39.6484, "lon": 27.8826},
    {"name": "Balıkesir", "district": "Bandırma", "lat": 40.3522, "lon": 27.9772},
    {"name": "Balıkesir", "district": "Edremit", "lat": 39.5953, "lon": 27.0253},
    {"name": "Balıkesir", "district": "Gönen", "lat": 40.1017, "lon": 27.6539},
    {"name": "Balıkesir", "district": "Ayvalık", "lat": 39.3189, "lon": 26.6933},
    
    # BİLECİK
    {"name": "Bilecik", "district": None, "lat": 40.0567, "lon": 30.0665},
    {"name": "Bilecik", "district": "Bozüyük", "lat": 39.9083, "lon": 30.0372},
    {"name": "Bilecik", "district": "Osmaneli", "lat": 40.3589, "lon": 30.0156},
    
    # BİNGÖL
    {"name": "Bingöl", "district": None, "lat": 38.8854, "lon": 40.4966},
    {"name": "Bingöl", "district": "Genç", "lat": 38.75, "lon": 40.55},
    {"name": "Bingöl", "district": "Karlıova", "lat": 39.3, "lon": 41.0167},
    
    # BİTLİS
    {"name": "Bitlis", "district": None, "lat": 38.4004, "lon": 42.1095},
    {"name": "Bitlis", "district": "Tatvan", "lat": 38.5, "lon": 42.2833},
    {"name": "Bitlis", "district": "Ahlat", "lat": 38.75, "lon": 42.4833},
    
    # BOLU
    {"name": "Bolu", "district": None, "lat": 40.7392, "lon": 31.6089},
    {"name": "Bolu", "district": "Gerede", "lat": 40.8, "lon": 32.1833},
    {"name": "Bolu", "district": "Mudurnu", "lat": 40.4667, "lon": 31.2},
    
    # BURDUR
    {"name": "Burdur", "district": None, "lat": 37.7203, "lon": 30.2906},
    {"name": "Burdur", "district": "Bucak", "lat": 37.4628, "lon": 30.5967},
    {"name": "Burdur", "district": "Gölhisar", "lat": 37.1442, "lon": 29.5075},
    
    # BURSA
    {"name": "Bursa", "district": None, "lat": 40.1826, "lon": 29.0665},
    {"name": "Bursa", "district": "İnegöl", "lat": 40.0781, "lon": 29.5133},
    {"name": "Bursa", "district": "Gemlik", "lat": 40.4331, "lon": 29.1572},
    {"name": "Bursa", "district": "Mudanya", "lat": 40.3764, "lon": 28.8828},
    {"name": "Bursa", "district": "Orhangazi", "lat": 40.4892, "lon": 29.3089},
    
    # ÇANAKKALE
    {"name": "Çanakkale", "district": None, "lat": 40.1553, "lon": 26.4142},
    {"name": "Çanakkale", "district": "Biga", "lat": 40.2289, "lon": 27.2442},
    {"name": "Çanakkale", "district": "Çan", "lat": 40.0333, "lon": 27.05},
    {"name": "Çanakkale", "district": "Gelibolu", "lat": 40.4108, "lon": 26.6708},
    
    # ÇANKIRI
    {"name": "Çankırı", "district": None, "lat": 40.6013, "lon": 33.6134},
    {"name": "Çankırı", "district": "Çerkeş", "lat": 40.8167, "lon": 32.8833},
    {"name": "Çankırı", "district": "Ilgaz", "lat": 40.9192, "lon": 33.6344},
    
    # ÇORUM
    {"name": "Çorum", "district": None, "lat": 40.5506, "lon": 34.9556},
    {"name": "Çorum", "district": "Osmancık", "lat": 40.9833, "lon": 34.8},
    {"name": "Çorum", "district": "Sungurlu", "lat": 40.1667, "lon": 34.3833},
    {"name": "Çorum", "district": "İskilip", "lat": 40.7333, "lon": 34.4833},
    
    # DENİZLİ
    {"name": "Denizli", "district": None, "lat": 37.7765, "lon": 29.0864},
    {"name": "Denizli", "district": "Çivril", "lat": 38.2986, "lon": 29.7386},
    {"name": "Denizli", "district": "Acıpayam", "lat": 37.4256, "lon": 29.3492},
    {"name": "Denizli", "district": "Tavas", "lat": 37.5667, "lon": 29.0667},
    
    # DİYARBAKIR
    {"name": "Diyarbakır", "district": None, "lat": 37.9144, "lon": 40.2306},
    {"name": "Diyarbakır", "district": "Bismil", "lat": 37.8444, "lon": 40.6653},
    {"name": "Diyarbakır", "district": "Silvan", "lat": 38.1333, "lon": 41.0167},
    {"name": "Diyarbakır", "district": "Ergani", "lat": 38.2667, "lon": 39.7667},
    
    # EDİRNE
    {"name": "Edirne", "district": None, "lat": 41.6818, "lon": 26.5623},
    {"name": "Edirne", "district": "Keşan", "lat": 40.8558, "lon": 26.6297},
    {"name": "Edirne", "district": "Uzunköprü", "lat": 41.2656, "lon": 26.6886},
    
    # ELAZIĞ
    {"name": "Elazığ", "district": None, "lat": 38.6810, "lon": 39.2264},
    {"name": "Elazığ", "district": "Kovancılar", "lat": 38.7167, "lon": 39.8667},
    {"name": "Elazığ", "district": "Karakoçan", "lat": 38.95, "lon": 40.0333},
    
    # ERZİNCAN
    {"name": "Erzincan", "district": None, "lat": 39.7500, "lon": 39.5000},
    {"name": "Erzincan", "district": "Tercan", "lat": 39.7833, "lon": 40.3833},
    {"name": "Erzincan", "district": "Refahiye", "lat": 39.9, "lon": 38.7667},
    
    # ERZURUM
    {"name": "Erzurum", "district": None, "lat": 39.9000, "lon": 41.2700},
    {"name": "Erzurum", "district": "Pasinler", "lat": 40.05, "lon": 42.0},
    {"name": "Erzurum", "district": "Horasan", "lat": 40.0417, "lon": 42.1722},
    {"name": "Erzurum", "district": "Oltu", "lat": 40.55, "lon": 41.9833},
    
    # ESKİŞEHİR
    {"name": "Eskişehir", "district": None, "lat": 39.7767, "lon": 30.5206},
    {"name": "Eskişehir", "district": "Sivrihisar", "lat": 39.45, "lon": 31.5333},
    {"name": "Eskişehir", "district": "Çifteler", "lat": 39.3833, "lon": 31.0333},
    
    # GAZİANTEP
    {"name": "Gaziantep", "district": None, "lat": 37.0662, "lon": 37.3833},
    {"name": "Gaziantep", "district": "Nizip", "lat": 37.0097, "lon": 37.7947},
    {"name": "Gaziantep", "district": "İslahiye", "lat": 37.0261, "lon": 36.6314},
    {"name": "Gaziantep", "district": "Karkamış", "lat": 36.8333, "lon": 37.9667},
    
    # GİRESUN
    {"name": "Giresun", "district": None, "lat": 40.9128, "lon": 38.3895},
    {"name": "Giresun", "district": "Bulancak", "lat": 40.9389, "lon": 38.2297},
    {"name": "Giresun", "district": "Espiye", "lat": 40.95, "lon": 38.7167},
    
    # GÜMÜŞHANE
    {"name": "Gümüşhane", "district": None, "lat": 40.4386, "lon": 39.5086},
    {"name": "Gümüşhane", "district": "Kelkit", "lat": 40.1333, "lon": 39.4333},
    {"name": "Gümüşhane", "district": "Şiran", "lat": 40.1919, "lon": 38.8906},
    
    # HAKKARİ
    {"name": "Hakkari", "district": None, "lat": 37.5833, "lon": 43.7333},
    {"name": "Hakkari", "district": "Yüksekova", "lat": 37.5736, "lon": 44.2856},
    {"name": "Hakkari", "district": "Şemdinli", "lat": 37.3, "lon": 44.5667},
    
    # HATAY
    {"name": "Hatay", "district": None, "lat": 36.4018, "lon": 36.3498},
    {"name": "Hatay", "district": "İskenderun", "lat": 36.5878, "lon": 36.1744},
    {"name": "Hatay", "district": "Dörtyol", "lat": 36.8494, "lon": 36.2214},
    {"name": "Hatay", "district": "Kırıkhan", "lat": 36.5, "lon": 36.5},
    {"name": "Hatay", "district": "Reyhanlı", "lat": 36.2683, "lon": 36.5669},
    
    # ISPARTA
    {"name": "Isparta", "district": None, "lat": 37.7648, "lon": 30.5566},
    {"name": "Isparta", "district": "Yalvaç", "lat": 38.2947, "lon": 31.1758},
    {"name": "Isparta", "district": "Eğirdir", "lat": 37.8667, "lon": 30.85},
    
    # MERSİN
    {"name": "Mersin", "district": None, "lat": 36.8121, "lon": 34.6415},
    {"name": "Mersin", "district": "Tarsus", "lat": 36.9181, "lon": 34.8936},
    {"name": "Mersin", "district": "Silifke", "lat": 36.3778, "lon": 33.9333},
    {"name": "Mersin", "district": "Anamur", "lat": 36.0794, "lon": 32.8344},
    {"name": "Mersin", "district": "Erdemli", "lat": 36.6058, "lon": 34.3069},
    
    # İSTANBUL
    {"name": "İstanbul", "district": None, "lat": 41.0082, "lon": 28.9784},
    {"name": "İstanbul", "district": "Kadıköy", "lat": 40.9833, "lon": 29.0333},
    {"name": "İstanbul", "district": "Üsküdar", "lat": 41.0214, "lon": 29.0167},
    {"name": "İstanbul", "district": "Beşiktaş", "lat": 41.0422, "lon": 29.0078},
    {"name": "İstanbul", "district": "Şişli", "lat": 41.0606, "lon": 28.9869},
    {"name": "İstanbul", "district": "Bakırköy", "lat": 40.9833, "lon": 28.8667},
    
    # İZMİR
    {"name": "İzmir", "district": None, "lat": 38.4237, "lon": 27.1428},
    {"name": "İzmir", "district": "Bergama", "lat": 39.1211, "lon": 27.1808},
    {"name": "İzmir", "district": "Tire", "lat": 38.0833, "lon": 27.7333},
    {"name": "İzmir", "district": "Ödemiş", "lat": 38.2333, "lon": 27.9667},
    {"name": "İzmir", "district": "Menemen", "lat": 38.6167, "lon": 27.0667},
    {"name": "İzmir", "district": "Torbalı", "lat": 38.15, "lon": 27.3667},
    
    # KARS
    {"name": "Kars", "district": None, "lat": 40.6167, "lon": 43.1000},
    {"name": "Kars", "district": "Sarıkamış", "lat": 40.3333, "lon": 42.5667},
    {"name": "Kars", "district": "Kağızman", "lat": 40.1667, "lon": 43.1333},
    
    # KASTAMONU
    {"name": "Kastamonu", "district": None, "lat": 41.3887, "lon": 33.7827},
    {"name": "Kastamonu", "district": "Tosya", "lat": 41.0167, "lon": 34.0333},
    {"name": "Kastamonu", "district": "Taşköprü", "lat": 41.5083, "lon": 34.2167},
    
    # KAYSERİ
    {"name": "Kayseri", "district": None, "lat": 38.7312, "lon": 35.4787},
    {"name": "Kayseri", "district": "Develi", "lat": 38.3833, "lon": 35.4833},
    {"name": "Kayseri", "district": "Yahyalı", "lat": 38.1, "lon": 35.3667},
    {"name": "Kayseri", "district": "Bünyan", "lat": 38.85, "lon": 35.85},
    
    # KIRKLARELİ
    {"name": "Kırklareli", "district": None, "lat": 41.7333, "lon": 27.2167},
    {"name": "Kırklareli", "district": "Lüleburgaz", "lat": 41.4039, "lon": 27.3597},
    {"name": "Kırklareli", "district": "Babaeski", "lat": 41.4333, "lon": 27.0833},
    
    # KIRŞEHİR
    {"name": "Kırşehir", "district": None, "lat": 39.1425, "lon": 34.1709},
    {"name": "Kırşehir", "district": "Kaman", "lat": 39.3583, "lon": 33.7267},
    {"name": "Kırşehir", "district": "Mucur", "lat": 39.0667, "lon": 34.3833},
    
    # KOCAELİ
    {"name": "Kocaeli", "district": None, "lat": 40.8533, "lon": 29.8815},
    {"name": "Kocaeli", "district": "Gebze", "lat": 40.7997, "lon": 29.4303},
    {"name": "Kocaeli", "district": "Gölcük", "lat": 40.7194, "lon": 29.8178},
    {"name": "Kocaeli", "district": "Derince", "lat": 40.7667, "lon": 29.85},
    
    # KONYA
    {"name": "Konya", "district": None, "lat": 37.8667, "lon": 32.4833},
    {"name": "Konya", "district": "Ereğli", "lat": 37.5139, "lon": 34.0478},
    {"name": "Konya", "district": "Beyşehir", "lat": 37.6667, "lon": 31.7333},
    {"name": "Konya", "district": "Seydişehir", "lat": 37.4167, "lon": 31.85},
    
    # KÜTAHYA
    {"name": "Kütahya", "district": None, "lat": 39.4167, "lon": 29.9833},
    {"name": "Kütahya", "district": "Tavşanlı", "lat": 39.5417, "lon": 29.4972},
    {"name": "Kütahya", "district": "Simav", "lat": 39.0903, "lon": 28.9789},
    {"name": "Kütahya", "district": "Gediz", "lat": 38.9917, "lon": 29.3917},
    
    # MALATYA
    {"name": "Malatya", "district": None, "lat": 38.3552, "lon": 38.3095},
    {"name": "Malatya", "district": "Akçadağ", "lat": 38.35, "lon": 37.9667},
    {"name": "Malatya", "district": "Darende", "lat": 38.55, "lon": 37.5},
    {"name": "Malatya", "district": "Doğanşehir", "lat": 38.0833, "lon": 37.8667},
    
    # MANİSA
    {"name": "Manisa", "district": None, "lat": 38.6191, "lon": 27.4289},
    {"name": "Manisa", "district": "Akhisar", "lat": 38.9167, "lon": 27.8333},
    {"name": "Manisa", "district": "Salihli", "lat": 38.4833, "lon": 28.1333},
    {"name": "Manisa", "district": "Turgutlu", "lat": 38.5, "lon": 27.7},
    {"name": "Manisa", "district": "Soma", "lat": 39.1833, "lon": 27.6},
    
    # KAHRAMANmaraş
    {"name": "Kahramanmaraş", "district": None, "lat": 37.5858, "lon": 36.9371},
    {"name": "Kahramanmaraş", "district": "Elbistan", "lat": 38.2, "lon": 37.1833},
    {"name": "Kahramanmaraş", "district": "Afşin", "lat": 38.25, "lon": 36.9167},
    {"name": "Kahramanmaraş", "district": "Pazarcık", "lat": 37.4833, "lon": 37.2833},
    
    # MARDİN
    {"name": "Mardin", "district": None, "lat": 37.3212, "lon": 40.7245},
    {"name": "Mardin", "district": "Kızıltepe", "lat": 37.1939, "lon": 40.5864},
    {"name": "Mardin", "district": "Nusaybin", "lat": 37.0667, "lon": 41.2167},
    {"name": "Mardin", "district": "Midyat", "lat": 37.4167, "lon": 41.3667},
    
    # MUĞLA
    {"name": "Muğla", "district": None, "lat": 37.2153, "lon": 28.3636},
    {"name": "Muğla", "district": "Bodrum", "lat": 37.0344, "lon": 27.4305},
    {"name": "Muğla", "district": "Fethiye", "lat": 36.6217, "lon": 29.1164},
    {"name": "Muğla", "district": "Marmaris", "lat": 36.8547, "lon": 28.2739},
    {"name": "Muğla", "district": "Milas", "lat": 37.3167, "lon": 27.7833},
    
    # MUŞ
    {"name": "Muş", "district": None, "lat": 38.9462, "lon": 41.7539},
    {"name": "Muş", "district": "Bulanık", "lat": 39.0833, "lon": 42.2667},
    {"name": "Muş", "district": "Varto", "lat": 39.1667, "lon": 41.45},
    
    # NEVŞEHİR
    {"name": "Nevşehir", "district": None, "lat": 38.6939, "lon": 34.6857},
    {"name": "Nevşehir", "district": "Avanos", "lat": 38.7167, "lon": 34.85},
    {"name": "Nevşehir", "district": "Ürgüp", "lat": 38.6333, "lon": 34.9167},
    
    # NİĞDE
    {"name": "Niğde", "district": None, "lat": 37.9667, "lon": 34.6833},
    {"name": "Niğde", "district": "Bor", "lat": 37.8833, "lon": 34.55},
    {"name": "Niğde", "district": "Çiftlik", "lat": 38.35, "lon": 34.4833},
    
    # ORDU
    {"name": "Ordu", "district": None, "lat": 40.9839, "lon": 37.8764},
    {"name": "Ordu", "district": "Ünye", "lat": 41.1272, "lon": 37.2881},
    {"name": "Ordu", "district": "Fatsa", "lat": 41.0333, "lon": 37.5},
    
    # OSMANİYE
    {"name": "Osmaniye", "district": None, "lat": 37.0742, "lon": 36.2478},
    {"name": "Osmaniye", "district": "Kadirli", "lat": 37.3744, "lon": 36.0992},
    {"name": "Osmaniye", "district": "Düziçi", "lat": 37.2667, "lon": 36.4667},
    {"name": "Osmaniye", "district": "Bahçe", "lat": 37.2, "lon": 36.5667},
    
    # RİZE
    {"name": "Rize", "district": None, "lat": 41.0201, "lon": 40.5234},
    {"name": "Rize", "district": "Ardeşen", "lat": 41.1903, "lon": 40.9875},
    {"name": "Rize", "district": "Pazar", "lat": 41.1772, "lon": 40.8894},
    
    # SAKARYA
    {"name": "Sakarya", "district": None, "lat": 40.6940, "lon": 30.4358},
    {"name": "Sakarya", "district": "Adapazarı", "lat": 40.7806, "lon": 30.4033},
    {"name": "Sakarya", "district": "Hendek", "lat": 40.8, "lon": 30.75},
    {"name": "Sakarya", "district": "Karasu", "lat": 41.0953, "lon": 30.6836},
    
    # SAMSUN
    {"name": "Samsun", "district": None, "lat": 41.2867, "lon": 36.33},
    {"name": "Samsun", "district": "Çarşamba", "lat": 41.2, "lon": 36.7167},
    {"name": "Samsun", "district": "Bafra", "lat": 41.5667, "lon": 35.9},
    {"name": "Samsun", "district": "Terme", "lat": 41.2167, "lon": 36.9667},
    
    # SİİRT
    {"name": "Siirt", "district": None, "lat": 37.9333, "lon": 41.95},
    {"name": "Siirt", "district": "Kurtalan", "lat": 37.9264, "lon": 41.6931},
    {"name": "Siirt", "district": "Pervari", "lat": 38.0167, "lon": 42.3667},
    
    # SİNOP
    {"name": "Sinop", "district": None, "lat": 42.0231, "lon": 35.1531},
    {"name": "Sinop", "district": "Boyabat", "lat": 41.4667, "lon": 34.7667},
    {"name": "Sinop", "district": "Ayancık", "lat": 41.9667, "lon": 34.6},
    
    # SİVAS
    {"name": "Sivas", "district": None, "lat": 39.7477, "lon": 37.0179},
    {"name": "Sivas", "district": "Şarkışla", "lat": 39.3667, "lon": 36.4},
    {"name": "Sivas", "district": "Gemerek", "lat": 39.1833, "lon": 36.0667},
    {"name": "Sivas", "district": "Kangal", "lat": 39.25, "lon": 37.4},
    
    # ŞANLIURFA
    {"name": "Şanlıurfa", "district": None, "lat": 37.1591, "lon": 38.7969},
    {"name": "Şanlıurfa", "district": "Viranşehir", "lat": 37.2333, "lon": 39.7667},
    {"name": "Şanlıurfa", "district": "Suruç", "lat": 36.9767, "lon": 38.4269},
    {"name": "Şanlıurfa", "district": "Birecik", "lat": 37.0278, "lon": 37.9778},
    
    # ŞIRNAK
    {"name": "Şırnak", "district": None, "lat": 37.4187, "lon": 42.4918},
    {"name": "Şırnak", "district": "Cizre", "lat": 37.3214, "lon": 42.1958},
    {"name": "Şırnak", "district": "Silopi", "lat": 37.2453, "lon": 42.4611},
    {"name": "Şırnak", "district": "İdil", "lat": 37.3333, "lon": 41.8833},
    
    # TEKİRDAĞ
    {"name": "Tekirdağ", "district": None, "lat": 40.9833, "lon": 27.5167},
    {"name": "Tekirdağ", "district": "Çorlu", "lat": 41.1597, "lon": 27.8006},
    {"name": "Tekirdağ", "district": "Çerkezköy", "lat": 41.2856, "lon": 28.0014},
    {"name": "Tekirdağ", "district": "Hayrabolu", "lat": 41.2167, "lon": 27.1},
    
    # TOKAT
    {"name": "Tokat", "district": None, "lat": 40.3167, "lon": 36.55},
    {"name": "Tokat", "district": "Erbaa", "lat": 40.6667, "lon": 36.5667},
    {"name": "Tokat", "district": "Turhal", "lat": 40.3833, "lon": 36.0833},
    {"name": "Tokat", "district": "Niksar", "lat": 40.5833, "lon": 36.95},
    
    # TRABZON
    {"name": "Trabzon", "district": None, "lat": 41.0015, "lon": 39.7178},
    {"name": "Trabzon", "district": "Akçaabat", "lat": 41.0167, "lon": 39.5667},
    {"name": "Trabzon", "district": "Vakfıkebir", "lat": 41.05, "lon": 39.2833},
    {"name": "Trabzon", "district": "Of", "lat": 40.9433, "lon": 40.2589},
    
    # TUNCELİ
    {"name": "Tunceli", "district": None, "lat": 39.1079, "lon": 39.5401},
    {"name": "Tunceli", "district": "Pertek", "lat": 38.8667, "lon": 39.3167},
    {"name": "Tunceli", "district": "Hozat", "lat": 39.2167, "lon": 39.2167},
    
    # UŞAK
    {"name": "Uşak", "district": None, "lat": 38.6823, "lon": 29.4082},
    {"name": "Uşak", "district": "Banaz", "lat": 38.7333, "lon": 29.75},
    {"name": "Uşak", "district": "Eşme", "lat": 38.4, "lon": 28.9667},
    
    # VAN
    {"name": "Van", "district": None, "lat": 38.4891, "lon": 43.4089},
    {"name": "Van", "district": "Erciş", "lat": 39.0167, "lon": 43.3667},
    {"name": "Van", "district": "Başkale", "lat": 38.0500, "lon": 44.0167},
    {"name": "Van", "district": "Özalp", "lat": 38.6667, "lon": 43.9833},
    
    # YALOVA
    {"name": "Yalova", "district": None, "lat": 40.6500, "lon": 29.2667},
    {"name": "Yalova", "district": "Çınarcık", "lat": 40.6333, "lon": 29.1167},
    {"name": "Yalova", "district": "Çiftlikköy", "lat": 40.6667, "lon": 29.3167},
    {"name": "Yalova", "district": "Altınova", "lat": 40.6833, "lon": 29.5167},
    
    # YOZGAT
    {"name": "Yozgat", "district": None, "lat": 39.82, "lon": 34.8147},
    {"name": "Yozgat", "district": "Sorgun", "lat": 39.8, "lon": 35.1833},
    {"name": "Yozgat", "district": "Boğazlıyan", "lat": 39.1922, "lon": 35.2469},
    
    # ZONGULDAK
    {"name": "Zonguldak", "district": None, "lat": 41.4564, "lon": 31.7987},
    {"name": "Zonguldak", "district": "Ereğli", "lat": 41.2833, "lon": 31.4167},
    {"name": "Zonguldak", "district": "Çaycuma", "lat": 41.4333, "lon": 32.0833},
    {"name": "Zonguldak", "district": "Devrek", "lat": 41.2167, "lon": 31.95},
    
    # AKSARAY
    {"name": "Aksaray", "district": None, "lat": 38.3687, "lon": 34.0370},
    {"name": "Aksaray", "district": "Ortaköy", "lat": 38.7333, "lon": 34.0167},
    {"name": "Aksaray", "district": "Güzelyurt", "lat": 38.2667, "lon": 34.3667},
    
    # BAYBURT
    {"name": "Bayburt", "district": None, "lat": 40.2552, "lon": 40.2249},
    {"name": "Bayburt", "district": "Demirözü", "lat": 40.1667, "lon": 39.8833},
    
    # KARAMAN
    {"name": "Karaman", "district": None, "lat": 37.1759, "lon": 33.2287},
    {"name": "Karaman", "district": "Ermenek", "lat": 36.6372, "lon": 32.8908},
    {"name": "Karaman", "district": "Ayrancı", "lat": 37.2572, "lon": 33.6408},
    
    # KIRIKKALE
    {"name": "Kırıkkale", "district": None, "lat": 39.8468, "lon": 33.5153},
    {"name": "Kırıkkale", "district": "Keskin", "lat": 39.6667, "lon": 33.6167},
    {"name": "Kırıkkale", "district": "Delice", "lat": 40.05, "lon": 34.05},
    
    # BATMAN
    {"name": "Batman", "district": None, "lat": 37.8812, "lon": 41.1351},
    {"name": "Batman", "district": "Kozluk", "lat": 38.1939, "lon": 41.4856},
    {"name": "Batman", "district": "Beşiri", "lat": 37.9333, "lon": 41.2667},
    
    # BARTIN
    {"name": "Bartın", "district": None, "lat": 41.6344, "lon": 32.3375},
    {"name": "Bartın", "district": "Amasra", "lat": 41.75, "lon": 32.3833},
    {"name": "Bartın", "district": "Ulus", "lat": 41.5833, "lon": 32.6333},
    
    # ARDAHAN
    {"name": "Ardahan", "district": None, "lat": 41.1105, "lon": 42.7022},
    {"name": "Ardahan", "district": "Göle", "lat": 40.7833, "lon": 42.6167},
    {"name": "Ardahan", "district": "Çıldır", "lat": 41.1333, "lon": 43.1333},
    
    # IĞDIR
    {"name": "Iğdır", "district": None, "lat": 39.9167, "lon": 44.0333},
    {"name": "Iğdır", "district": "Tuzluca", "lat": 40.0500, "lon": 43.6500},
    
    # KİLİS
    {"name": "Kilis", "district": None, "lat": 36.7184, "lon": 37.1212},
    {"name": "Kilis", "district": "Elbeyli", "lat": 36.6667, "lon": 37.5333},
    
    # DÜZCE
    {"name": "Düzce", "district": None, "lat": 40.8438, "lon": 31.1565},
    {"name": "Düzce", "district": "Akçakoca", "lat": 41.0858, "lon": 31.1181},
    {"name": "Düzce", "district": "Gölyaka", "lat": 40.7833, "lon": 31.0333},
    
    # KARABÜK
    {"name": "Karabük", "district": None, "lat": 41.2061, "lon": 32.6204},
    {"name": "Karabük", "district": "Safranbolu", "lat": 41.25, "lon": 32.6833},
    {"name": "Karabük", "district": "Yenice", "lat": 41.2, "lon": 32.35},
]

def get_city_coordinates():
    """Şehir ismi -> (lat, lon) dictionary döndürür (sadece il merkezleri)."""
    return {city["name"]: (city["lat"], city["lon"]) for city in TURKEY_CITIES if city.get("district") is None}

def get_all_cities():
    """Tüm şehirleri döndürür."""
    return TURKEY_CITIES

def get_all_locations():
    """Tüm şehir ve ilçeleri döndürür."""
    return TURKEY_CITIES
