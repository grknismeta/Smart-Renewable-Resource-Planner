"""
Türkiye'nin 81 İli ve Önemli İlçeleri - Koordinatlar ve Bilgiler
Her kayıt için 'name' alanı o konumun gerçek adını (İlçe veya Merkez) temsil eder.
'province' alanı ise bağlı olduğu ili belirtir.
"""

TURKEY_CITIES = [
    # ADANA
    {"name": "Adana", "province": "Adana", "district": None, "lat": 37.0000, "lon": 35.3213},
    {"name": "Ceyhan", "province": "Adana", "district": "Ceyhan", "lat": 37.0297, "lon": 35.8169},
    {"name": "Kozan", "province": "Adana", "district": "Kozan", "lat": 37.4514, "lon": 35.8169},
    {"name": "Yumurtalık", "province": "Adana", "district": "Yumurtalık", "lat": 36.7667, "lon": 35.7833},
    
    # ADIYAMAN
    {"name": "Adıyaman", "province": "Adıyaman", "district": None, "lat": 37.7648, "lon": 38.2786},
    {"name": "Kahta", "province": "Adıyaman", "district": "Kahta", "lat": 37.7833, "lon": 38.6167},
    {"name": "Besni", "province": "Adıyaman", "district": "Besni", "lat": 37.6933, "lon": 37.8556},
    
    # AFYONKARAHİSAR
    {"name": "Afyonkarahisar", "province": "Afyonkarahisar", "district": None, "lat": 38.7507, "lon": 30.5567},
    {"name": "Sandıklı", "province": "Afyonkarahisar", "district": "Sandıklı", "lat": 38.4667, "lon": 30.2667},
    {"name": "Dinar", "province": "Afyonkarahisar", "district": "Dinar", "lat": 38.0667, "lon": 30.1667},
    {"name": "Bolvadin", "province": "Afyonkarahisar", "district": "Bolvadin", "lat": 38.7167, "lon": 31.0500},
    
    # AĞRI
    {"name": "Ağrı", "province": "Ağrı", "district": None, "lat": 39.7191, "lon": 43.0503},
    {"name": "Doğubayazıt", "province": "Ağrı", "district": "Doğubayazıt", "lat": 39.5475, "lon": 44.0833},
    {"name": "Patnos", "province": "Ağrı", "district": "Patnos", "lat": 39.2333, "lon": 42.8667},
    
    # AMASYA
    {"name": "Amasya", "province": "Amasya", "district": None, "lat": 40.6499, "lon": 35.8353},
    {"name": "Merzifon", "province": "Amasya", "district": "Merzifon", "lat": 40.8667, "lon": 35.4667},
    {"name": "Suluova", "province": "Amasya", "district": "Suluova", "lat": 40.8333, "lon": 35.6500},
    
    # ANKARA
    {"name": "Ankara", "province": "Ankara", "district": None, "lat": 39.9334, "lon": 32.8597},
    {"name": "Polatlı", "province": "Ankara", "district": "Polatlı", "lat": 39.5833, "lon": 32.1500},
    {"name": "Çubuk", "province": "Ankara", "district": "Çubuk", "lat": 40.2333, "lon": 33.0333},
    {"name": "Beypazarı", "province": "Ankara", "district": "Beypazarı", "lat": 40.1667, "lon": 31.9167},
    {"name": "Şereflikoçhisar", "province": "Ankara", "district": "Şereflikoçhisar", "lat": 38.9333, "lon": 33.5333},
    
    # ANTALYA
    {"name": "Antalya", "province": "Antalya", "district": None, "lat": 36.8969, "lon": 30.7133},
    {"name": "Alanya", "province": "Antalya", "district": "Alanya", "lat": 36.5444, "lon": 31.9956},
    {"name": "Manavgat", "province": "Antalya", "district": "Manavgat", "lat": 36.7878, "lon": 31.4442},
    {"name": "Kumluca", "province": "Antalya", "district": "Kumluca", "lat": 36.3667, "lon": 30.2833},
    {"name": "Serik", "province": "Antalya", "district": "Serik", "lat": 36.9167, "lon": 31.1000},
    {"name": "Kaş", "province": "Antalya", "district": "Kaş", "lat": 36.2019, "lon": 29.6414},
    
    # ARTVİN
    {"name": "Artvin", "province": "Artvin", "district": None, "lat": 41.1828, "lon": 41.8183},
    {"name": "Hopa", "province": "Artvin", "district": "Hopa", "lat": 41.4000, "lon": 41.4167},
    {"name": "Arhavi", "province": "Artvin", "district": "Arhavi", "lat": 41.3500, "lon": 41.3000},
    
    # AYDIN
    {"name": "Aydın", "province": "Aydın", "district": None, "lat": 37.8560, "lon": 27.8416},
    {"name": "Nazilli", "province": "Aydın", "district": "Nazilli", "lat": 37.9167, "lon": 28.3167},
    {"name": "Söke", "province": "Aydın", "district": "Söke", "lat": 37.7500, "lon": 27.4167},
    {"name": "Kuşadası", "province": "Aydın", "district": "Kuşadası", "lat": 37.8594, "lon": 27.2639},
    {"name": "Didim", "province": "Aydın", "district": "Didim", "lat": 37.3667, "lon": 27.2667},
    
    # BALIKESİR
    {"name": "Balıkesir", "province": "Balıkesir", "district": None, "lat": 39.6484, "lon": 27.8826},
    {"name": "Bandırma", "province": "Balıkesir", "district": "Bandırma", "lat": 40.3522, "lon": 27.9772},
    {"name": "Edremit", "province": "Balıkesir", "district": "Edremit", "lat": 39.5953, "lon": 27.0253},
    {"name": "Gönen", "province": "Balıkesir", "district": "Gönen", "lat": 40.1017, "lon": 27.6539},
    {"name": "Ayvalık", "province": "Balıkesir", "district": "Ayvalık", "lat": 39.3189, "lon": 26.6933},
    
    # BİLECİK
    {"name": "Bilecik", "province": "Bilecik", "district": None, "lat": 40.0567, "lon": 30.0665},
    {"name": "Bozüyük", "province": "Bilecik", "district": "Bozüyük", "lat": 39.9083, "lon": 30.0372},
    {"name": "Osmaneli", "province": "Bilecik", "district": "Osmaneli", "lat": 40.3589, "lon": 30.0156},
    
    # BİNGÖL
    {"name": "Bingöl", "province": "Bingöl", "district": None, "lat": 38.8854, "lon": 40.4966},
    {"name": "Genç", "province": "Bingöl", "district": "Genç", "lat": 38.7500, "lon": 40.5500},
    {"name": "Karlıova", "province": "Bingöl", "district": "Karlıova", "lat": 39.3000, "lon": 41.0167},
    
    # BİTLİS
    {"name": "Bitlis", "province": "Bitlis", "district": None, "lat": 38.4004, "lon": 42.1095},
    {"name": "Tatvan", "province": "Bitlis", "district": "Tatvan", "lat": 38.5000, "lon": 42.2833},
    {"name": "Ahlat", "province": "Bitlis", "district": "Ahlat", "lat": 38.7500, "lon": 42.4833},
    
    # BOLU
    {"name": "Bolu", "province": "Bolu", "district": None, "lat": 40.7392, "lon": 31.6089},
    {"name": "Gerede", "province": "Bolu", "district": "Gerede", "lat": 40.8000, "lon": 32.1833},
    {"name": "Mudurnu", "province": "Bolu", "district": "Mudurnu", "lat": 40.4667, "lon": 31.2000},
    
    # BURDUR
    {"name": "Burdur", "province": "Burdur", "district": None, "lat": 37.7203, "lon": 30.2906},
    {"name": "Bucak", "province": "Burdur", "district": "Bucak", "lat": 37.4628, "lon": 30.5967},
    {"name": "Gölhisar", "province": "Burdur", "district": "Gölhisar", "lat": 37.1442, "lon": 29.5075},
    
    # BURSA
    {"name": "Bursa", "province": "Bursa", "district": None, "lat": 40.1826, "lon": 29.0665},
    {"name": "İnegöl", "province": "Bursa", "district": "İnegöl", "lat": 40.0781, "lon": 29.5133},
    {"name": "Gemlik", "province": "Bursa", "district": "Gemlik", "lat": 40.4331, "lon": 29.1572},
    {"name": "Mudanya", "province": "Bursa", "district": "Mudanya", "lat": 40.3764, "lon": 28.8828},
    {"name": "Orhangazi", "province": "Bursa", "district": "Orhangazi", "lat": 40.4892, "lon": 29.3089},
    
    # ÇANAKKALE
    {"name": "Çanakkale", "province": "Çanakkale", "district": None, "lat": 40.1553, "lon": 26.4142},
    {"name": "Biga", "province": "Çanakkale", "district": "Biga", "lat": 40.2289, "lon": 27.2442},
    {"name": "Çan", "province": "Çanakkale", "district": "Çan", "lat": 40.0333, "lon": 27.0500},
    {"name": "Gelibolu", "province": "Çanakkale", "district": "Gelibolu", "lat": 40.4108, "lon": 26.6708},
    
    # ÇANKIRI
    {"name": "Çankırı", "province": "Çankırı", "district": None, "lat": 40.6013, "lon": 33.6134},
    {"name": "Çerkeş", "province": "Çankırı", "district": "Çerkeş", "lat": 40.8167, "lon": 32.8833},
    {"name": "Ilgaz", "province": "Çankırı", "district": "Ilgaz", "lat": 40.9192, "lon": 33.6344},
    
    # ÇORUM
    {"name": "Çorum", "province": "Çorum", "district": None, "lat": 40.5506, "lon": 34.9556},
    {"name": "Osmancık", "province": "Çorum", "district": "Osmancık", "lat": 40.9833, "lon": 34.8000},
    {"name": "Sungurlu", "province": "Çorum", "district": "Sungurlu", "lat": 40.1667, "lon": 34.3833},
    {"name": "İskilip", "province": "Çorum", "district": "İskilip", "lat": 40.7333, "lon": 34.4833},
    
    # DENİZLİ
    {"name": "Denizli", "province": "Denizli", "district": None, "lat": 37.7765, "lon": 29.0864},
    {"name": "Çivril", "province": "Denizli", "district": "Çivril", "lat": 38.2986, "lon": 29.7386},
    {"name": "Acıpayam", "province": "Denizli", "district": "Acıpayam", "lat": 37.4256, "lon": 29.3492},
    {"name": "Tavas", "province": "Denizli", "district": "Tavas", "lat": 37.5667, "lon": 29.0667},
    
    # DİYARBAKIR
    {"name": "Diyarbakır", "province": "Diyarbakır", "district": None, "lat": 37.9144, "lon": 40.2306},
    {"name": "Bismil", "province": "Diyarbakır", "district": "Bismil", "lat": 37.8444, "lon": 40.6653},
    {"name": "Silvan", "province": "Diyarbakır", "district": "Silvan", "lat": 38.1333, "lon": 41.0167},
    {"name": "Ergani", "province": "Diyarbakır", "district": "Ergani", "lat": 38.2667, "lon": 39.7667},
    
    # EDİRNE
    {"name": "Edirne", "province": "Edirne", "district": None, "lat": 41.6818, "lon": 26.5623},
    {"name": "Keşan", "province": "Edirne", "district": "Keşan", "lat": 40.8558, "lon": 26.6297},
    {"name": "Uzunköprü", "province": "Edirne", "district": "Uzunköprü", "lat": 41.2656, "lon": 26.6886},
    
    # ELAZIĞ
    {"name": "Elazığ", "province": "Elazığ", "district": None, "lat": 38.6810, "lon": 39.2264},
    {"name": "Kovancılar", "province": "Elazığ", "district": "Kovancılar", "lat": 38.7167, "lon": 39.8667},
    {"name": "Karakoçan", "province": "Elazığ", "district": "Karakoçan", "lat": 38.9500, "lon": 40.0333},
    
    # ERZİNCAN
    {"name": "Erzincan", "province": "Erzincan", "district": None, "lat": 39.7500, "lon": 39.5000},
    {"name": "Tercan", "province": "Erzincan", "district": "Tercan", "lat": 39.7833, "lon": 40.3833},
    {"name": "Refahiye", "province": "Erzincan", "district": "Refahiye", "lat": 39.9000, "lon": 38.7667},
    
    # ERZURUM
    {"name": "Erzurum", "province": "Erzurum", "district": None, "lat": 39.9000, "lon": 41.2700},
    {"name": "Pasinler", "province": "Erzurum", "district": "Pasinler", "lat": 40.0500, "lon": 42.0000},
    {"name": "Horasan", "province": "Erzurum", "district": "Horasan", "lat": 40.0417, "lon": 42.1722},
    {"name": "Oltu", "province": "Erzurum", "district": "Oltu", "lat": 40.5500, "lon": 41.9833},
    
    # ESKİŞEHİR
    {"name": "Eskişehir", "province": "Eskişehir", "district": None, "lat": 39.7767, "lon": 30.5206},
    {"name": "Sivrihisar", "province": "Eskişehir", "district": "Sivrihisar", "lat": 39.4500, "lon": 31.5333},
    {"name": "Çifteler", "province": "Eskişehir", "district": "Çifteler", "lat": 39.3833, "lon": 31.0333},
    
    # GAZİANTEP
    {"name": "Gaziantep", "province": "Gaziantep", "district": None, "lat": 37.0662, "lon": 37.3833},
    {"name": "Nizip", "province": "Gaziantep", "district": "Nizip", "lat": 37.0097, "lon": 37.7947},
    {"name": "İslahiye", "province": "Gaziantep", "district": "İslahiye", "lat": 37.0261, "lon": 36.6314},
    {"name": "Karkamış", "province": "Gaziantep", "district": "Karkamış", "lat": 36.8333, "lon": 37.9667},
    
    # GİRESUN
    {"name": "Giresun", "province": "Giresun", "district": None, "lat": 40.8900, "lon": 38.3895},
    {"name": "Bulancak", "province": "Giresun", "district": "Bulancak", "lat": 40.9389, "lon": 38.2297},
    {"name": "Espiye", "province": "Giresun", "district": "Espiye", "lat": 40.9500, "lon": 38.7167},
    
    # GÜMÜŞHANE
    {"name": "Gümüşhane", "province": "Gümüşhane", "district": None, "lat": 40.4386, "lon": 39.5086},
    {"name": "Kelkit", "province": "Gümüşhane", "district": "Kelkit", "lat": 40.1333, "lon": 39.4333},
    {"name": "Şiran", "province": "Gümüşhane", "district": "Şiran", "lat": 40.1919, "lon": 38.8906},
    
    # HAKKARİ
    {"name": "Hakkari", "province": "Hakkari", "district": None, "lat": 37.5833, "lon": 43.7333},
    {"name": "Yüksekova", "province": "Hakkari", "district": "Yüksekova", "lat": 37.5736, "lon": 44.2856},
    {"name": "Şemdinli", "province": "Hakkari", "district": "Şemdinli", "lat": 37.3000, "lon": 44.5667},
    
    # HATAY
    {"name": "Antakya", "province": "Hatay", "district": None, "lat": 36.2023, "lon": 36.1613},
    {"name": "İskenderun", "province": "Hatay", "district": "İskenderun", "lat": 36.5878, "lon": 36.1744},
    {"name": "Dörtyol", "province": "Hatay", "district": "Dörtyol", "lat": 36.8494, "lon": 36.2214},
    {"name": "Kırıkhan", "province": "Hatay", "district": "Kırıkhan", "lat": 36.5000, "lon": 36.3500},
    {"name": "Reyhanlı", "province": "Hatay", "district": "Reyhanlı", "lat": 36.2683, "lon": 36.5669},
    
    # ISPARTA
    {"name": "Isparta", "province": "Isparta", "district": None, "lat": 37.7648, "lon": 30.5566},
    {"name": "Yalvaç", "province": "Isparta", "district": "Yalvaç", "lat": 38.2947, "lon": 31.1758},
    {"name": "Eğirdir", "province": "Isparta", "district": "Eğirdir", "lat": 37.8667, "lon": 30.8500},
    
    # MERSİN
    {"name": "Mersin", "province": "Mersin", "district": None, "lat": 36.8121, "lon": 34.6415},
    {"name": "Tarsus", "province": "Mersin", "district": "Tarsus", "lat": 36.9181, "lon": 34.8936},
    {"name": "Silifke", "province": "Mersin", "district": "Silifke", "lat": 36.3778, "lon": 33.9333},
    {"name": "Anamur", "province": "Mersin", "district": "Anamur", "lat": 36.0794, "lon": 32.8344},
    {"name": "Erdemli", "province": "Mersin", "district": "Erdemli", "lat": 36.6058, "lon": 34.3069},
    
    # İSTANBUL
    {"name": "İstanbul", "province": "İstanbul", "district": None, "lat": 41.0082, "lon": 28.9784},
    {"name": "Kadıköy", "province": "İstanbul", "district": "Kadıköy", "lat": 40.9833, "lon": 29.0333},
    {"name": "Üsküdar", "province": "İstanbul", "district": "Üsküdar", "lat": 41.0214, "lon": 29.0167},
    {"name": "Beşiktaş", "province": "İstanbul", "district": "Beşiktaş", "lat": 41.0422, "lon": 29.0078},
    {"name": "Şişli", "province": "İstanbul", "district": "Şişli", "lat": 41.0606, "lon": 28.9869},
    {"name": "Bakırköy", "province": "İstanbul", "district": "Bakırköy", "lat": 40.9833, "lon": 28.8667},
    
    # İZMİR
    {"name": "İzmir", "province": "İzmir", "district": None, "lat": 38.4237, "lon": 27.1428},
    {"name": "Bergama", "province": "İzmir", "district": "Bergama", "lat": 39.1211, "lon": 27.1808},
    {"name": "Tire", "province": "İzmir", "district": "Tire", "lat": 38.0833, "lon": 27.7333},
    {"name": "Ödemiş", "province": "İzmir", "district": "Ödemiş", "lat": 38.2333, "lon": 27.9667},
    {"name": "Menemen", "province": "İzmir", "district": "Menemen", "lat": 38.6167, "lon": 27.0667},
    {"name": "Torbalı", "province": "İzmir", "district": "Torbalı", "lat": 38.1500, "lon": 27.3667},
    
    # KARS
    {"name": "Kars", "province": "Kars", "district": None, "lat": 40.6167, "lon": 43.1000},
    {"name": "Sarıkamış", "province": "Kars", "district": "Sarıkamış", "lat": 40.3333, "lon": 42.5667},
    {"name": "Kağızman", "province": "Kars", "district": "Kağızman", "lat": 40.1667, "lon": 43.1333},
    
    # KASTAMONU
    {"name": "Kastamonu", "province": "Kastamonu", "district": None, "lat": 41.3887, "lon": 33.7827},
    {"name": "Tosya", "province": "Kastamonu", "district": "Tosya", "lat": 41.0167, "lon": 34.0333},
    {"name": "Taşköprü", "province": "Kastamonu", "district": "Taşköprü", "lat": 41.5083, "lon": 34.2167},
    
    # KAYSERİ
    {"name": "Kayseri", "province": "Kayseri", "district": None, "lat": 38.7312, "lon": 35.4787},
    {"name": "Develi", "province": "Kayseri", "district": "Develi", "lat": 38.3833, "lon": 35.4833},
    {"name": "Yahyalı", "province": "Kayseri", "district": "Yahyalı", "lat": 38.1000, "lon": 35.3667},
    {"name": "Bünyan", "province": "Kayseri", "district": "Bünyan", "lat": 38.8500, "lon": 35.8500},
    
    # KIRKLARELİ
    {"name": "Kırklareli", "province": "Kırklareli", "district": None, "lat": 41.7333, "lon": 27.2167},
    {"name": "Lüleburgaz", "province": "Kırklareli", "district": "Lüleburgaz", "lat": 41.4039, "lon": 27.3597},
    {"name": "Babaeski", "province": "Kırklareli", "district": "Babaeski", "lat": 41.4333, "lon": 27.0833},
    
    # KIRŞEHİR
    {"name": "Kırşehir", "province": "Kırşehir", "district": None, "lat": 39.1425, "lon": 34.1709},
    {"name": "Kaman", "province": "Kırşehir", "district": "Kaman", "lat": 39.3583, "lon": 33.7267},
    {"name": "Mucur", "province": "Kırşehir", "district": "Mucur", "lat": 39.0667, "lon": 34.3833},
    
    # KOCAELİ
    {"name": "İzmit", "province": "Kocaeli", "district": None, "lat": 40.7654, "lon": 29.9408},
    {"name": "Gebze", "province": "Kocaeli", "district": "Gebze", "lat": 40.7997, "lon": 29.4303},
    {"name": "Gölcük", "province": "Kocaeli", "district": "Gölcük", "lat": 40.7194, "lon": 29.8178},
    {"name": "Derince", "province": "Kocaeli", "district": "Derince", "lat": 40.7667, "lon": 29.8500},
    
    # KONYA
    {"name": "Konya", "province": "Konya", "district": None, "lat": 37.8667, "lon": 32.4833},
    {"name": "Ereğli", "province": "Konya", "district": "Ereğli", "lat": 37.5139, "lon": 34.0478},
    {"name": "Beyşehir", "province": "Konya", "district": "Beyşehir", "lat": 37.6667, "lon": 31.7333},
    {"name": "Seydişehir", "province": "Konya", "district": "Seydişehir", "lat": 37.4167, "lon": 31.8500},
    
    # KÜTAHYA
    {"name": "Kütahya", "province": "Kütahya", "district": None, "lat": 39.4167, "lon": 29.9833},
    {"name": "Tavşanlı", "province": "Kütahya", "district": "Tavşanlı", "lat": 39.5417, "lon": 29.4972},
    {"name": "Simav", "province": "Kütahya", "district": "Simav", "lat": 39.0903, "lon": 28.9789},
    {"name": "Gediz", "province": "Kütahya", "district": "Gediz", "lat": 38.9917, "lon": 29.3917},
    
    # MALATYA
    {"name": "Malatya", "province": "Malatya", "district": None, "lat": 38.3552, "lon": 38.3095},
    {"name": "Akçadağ", "province": "Malatya", "district": "Akçadağ", "lat": 38.3500, "lon": 37.9667},
    {"name": "Darende", "province": "Malatya", "district": "Darende", "lat": 38.5500, "lon": 37.5000},
    {"name": "Doğanşehir", "province": "Malatya", "district": "Doğanşehir", "lat": 38.0833, "lon": 37.8667},
    
    # MANİSA
    {"name": "Manisa", "province": "Manisa", "district": None, "lat": 38.6191, "lon": 27.4289},
    {"name": "Akhisar", "province": "Manisa", "district": "Akhisar", "lat": 38.9167, "lon": 27.8333},
    {"name": "Salihli", "province": "Manisa", "district": "Salihli", "lat": 38.4833, "lon": 28.1333},
    {"name": "Turgutlu", "province": "Manisa", "district": "Turgutlu", "lat": 38.5000, "lon": 27.7000},
    {"name": "Soma", "province": "Manisa", "district": "Soma", "lat": 39.1833, "lon": 27.6000},
    
    # KAHRAMANMARAŞ
    {"name": "Kahramanmaraş", "province": "Kahramanmaraş", "district": None, "lat": 37.5858, "lon": 36.9371},
    {"name": "Elbistan", "province": "Kahramanmaraş", "district": "Elbistan", "lat": 38.2000, "lon": 37.1833},
    {"name": "Afşin", "province": "Kahramanmaraş", "district": "Afşin", "lat": 38.2500, "lon": 36.9167},
    {"name": "Pazarcık", "province": "Kahramanmaraş", "district": "Pazarcık", "lat": 37.4833, "lon": 37.2833},
    
    # MARDİN
    {"name": "Mardin", "province": "Mardin", "district": None, "lat": 37.3212, "lon": 40.7245},
    {"name": "Kızıltepe", "province": "Mardin", "district": "Kızıltepe", "lat": 37.1939, "lon": 40.5864},
    {"name": "Nusaybin", "province": "Mardin", "district": "Nusaybin", "lat": 37.0667, "lon": 41.2167},
    {"name": "Midyat", "province": "Mardin", "district": "Midyat", "lat": 37.4167, "lon": 41.3667},
    
    # MUĞLA
    {"name": "Muğla", "province": "Muğla", "district": None, "lat": 37.2153, "lon": 28.3636},
    {"name": "Bodrum", "province": "Muğla", "district": "Bodrum", "lat": 37.0344, "lon": 27.4305},
    {"name": "Fethiye", "province": "Muğla", "district": "Fethiye", "lat": 36.6217, "lon": 29.1164},
    {"name": "Marmaris", "province": "Muğla", "district": "Marmaris", "lat": 36.8547, "lon": 28.2739},
    {"name": "Milas", "province": "Muğla", "district": "Milas", "lat": 37.3167, "lon": 27.7833},
    
    # MUŞ
    {"name": "Muş", "province": "Muş", "district": None, "lat": 38.9462, "lon": 41.7539},
    {"name": "Bulanık", "province": "Muş", "district": "Bulanık", "lat": 39.0833, "lon": 42.2667},
    {"name": "Varto", "province": "Muş", "district": "Varto", "lat": 39.1667, "lon": 41.4500},
    
    # NEVŞEHİR
    {"name": "Nevşehir", "province": "Nevşehir", "district": None, "lat": 38.6939, "lon": 34.6857},
    {"name": "Avanos", "province": "Nevşehir", "district": "Avanos", "lat": 38.7167, "lon": 34.8500},
    {"name": "Ürgüp", "province": "Nevşehir", "district": "Ürgüp", "lat": 38.6333, "lon": 34.9167},
    
    # NİĞDE
    {"name": "Niğde", "province": "Niğde", "district": None, "lat": 37.9667, "lon": 34.6833},
    {"name": "Bor", "province": "Niğde", "district": "Bor", "lat": 37.8833, "lon": 34.5500},
    {"name": "Çiftlik", "province": "Niğde", "district": "Çiftlik", "lat": 38.3500, "lon": 34.4833},
    
    # ORDU
    {"name": "Ordu", "province": "Ordu", "district": None, "lat": 40.9500, "lon": 37.8764},
    {"name": "Ünye", "province": "Ordu", "district": "Ünye", "lat": 41.1272, "lon": 37.2881},
    {"name": "Fatsa", "province": "Ordu", "district": "Fatsa", "lat": 41.0333, "lon": 37.5000},
    
    # OSMANİYE
    {"name": "Osmaniye", "province": "Osmaniye", "district": None, "lat": 37.0742, "lon": 36.2478},
    {"name": "Kadirli", "province": "Osmaniye", "district": "Kadirli", "lat": 37.3744, "lon": 36.0992},
    {"name": "Düziçi", "province": "Osmaniye", "district": "Düziçi", "lat": 37.2667, "lon": 36.4667},
    {"name": "Bahçe", "province": "Osmaniye", "district": "Bahçe", "lat": 37.2000, "lon": 36.5667},
    
    # RİZE
    {"name": "Rize", "province": "Rize", "district": None, "lat": 40.9800, "lon": 40.5234},
    {"name": "Ardeşen", "province": "Rize", "district": "Ardeşen", "lat": 41.1903, "lon": 40.9875},
    {"name": "Pazar", "province": "Rize", "district": "Pazar", "lat": 41.1772, "lon": 40.8894},
    
    # SAKARYA
    {"name": "Sakarya", "province": "Sakarya", "district": None, "lat": 40.6940, "lon": 30.4358},
    {"name": "Adapazarı", "province": "Sakarya", "district": "Adapazarı", "lat": 40.7806, "lon": 30.4033},
    {"name": "Hendek", "province": "Sakarya", "district": "Hendek", "lat": 40.8000, "lon": 30.7500},
    {"name": "Karasu", "province": "Sakarya", "district": "Karasu", "lat": 41.0953, "lon": 30.6836},
    
    # SAMSUN
    {"name": "Samsun", "province": "Samsun", "district": None, "lat": 41.2500, "lon": 36.3300},
    {"name": "Çarşamba", "province": "Samsun", "district": "Çarşamba", "lat": 41.2000, "lon": 36.7167},
    {"name": "Bafra", "province": "Samsun", "district": "Bafra", "lat": 41.5667, "lon": 35.9000},
    {"name": "Terme", "province": "Samsun", "district": "Terme", "lat": 41.2167, "lon": 36.9667},
    
    # SİİRT
    {"name": "Siirt", "province": "Siirt", "district": None, "lat": 37.9333, "lon": 41.9500},
    {"name": "Kurtalan", "province": "Siirt", "district": "Kurtalan", "lat": 37.9264, "lon": 41.6931},
    {"name": "Pervari", "province": "Siirt", "district": "Pervari", "lat": 38.0167, "lon": 42.3667},
    
    # SİNOP
    {"name": "Sinop", "province": "Sinop", "district": None, "lat": 42.0206, "lon": 35.1156},
    {"name": "Boyabat", "province": "Sinop", "district": "Boyabat", "lat": 41.4667, "lon": 34.7667},
    {"name": "Ayancık", "province": "Sinop", "district": "Ayancık", "lat": 41.9404, "lon": 34.5898},
    
    # SİVAS
    {"name": "Sivas", "province": "Sivas", "district": None, "lat": 39.7477, "lon": 37.0179},
    {"name": "Şarkışla", "province": "Sivas", "district": "Şarkışla", "lat": 39.3667, "lon": 36.4000},
    {"name": "Gemerek", "province": "Sivas", "district": "Gemerek", "lat": 39.1833, "lon": 36.0667},
    {"name": "Kangal", "province": "Sivas", "district": "Kangal", "lat": 39.2500, "lon": 37.4000},
    
    # ŞANLIURFA
    {"name": "Şanlıurfa", "province": "Şanlıurfa", "district": None, "lat": 37.1591, "lon": 38.7969},
    {"name": "Viranşehir", "province": "Şanlıurfa", "district": "Viranşehir", "lat": 37.2333, "lon": 39.7667},
    {"name": "Suruç", "province": "Şanlıurfa", "district": "Suruç", "lat": 36.9767, "lon": 38.4269},
    {"name": "Birecik", "province": "Şanlıurfa", "district": "Birecik", "lat": 37.0278, "lon": 37.9778},
    
    # ŞIRNAK
    {"name": "Şırnak", "province": "Şırnak", "district": None, "lat": 37.4187, "lon": 42.4918},
    {"name": "Cizre", "province": "Şırnak", "district": "Cizre", "lat": 37.3214, "lon": 42.1958},
    {"name": "Silopi", "province": "Şırnak", "district": "Silopi", "lat": 37.2453, "lon": 42.4611},
    {"name": "İdil", "province": "Şırnak", "district": "İdil", "lat": 37.3333, "lon": 41.8833},
    
    # TEKİRDAĞ
    {"name": "Tekirdağ", "province": "Tekirdağ", "district": None, "lat": 40.9833, "lon": 27.5167},
    {"name": "Çorlu", "province": "Tekirdağ", "district": "Çorlu", "lat": 41.1597, "lon": 27.8006},
    {"name": "Çerkezköy", "province": "Tekirdağ", "district": "Çerkezköy", "lat": 41.2856, "lon": 28.0014},
    {"name": "Hayrabolu", "province": "Tekirdağ", "district": "Hayrabolu", "lat": 41.2167, "lon": 27.1000},
    
    # TOKAT
    {"name": "Tokat", "province": "Tokat", "district": None, "lat": 40.3167, "lon": 36.5500},
    {"name": "Erbaa", "province": "Tokat", "district": "Erbaa", "lat": 40.6667, "lon": 36.5667},
    {"name": "Turhal", "province": "Tokat", "district": "Turhal", "lat": 40.3833, "lon": 36.0833},
    {"name": "Niksar", "province": "Tokat", "district": "Niksar", "lat": 40.5833, "lon": 36.9500},
    
    # TRABZON
    {"name": "Trabzon", "province": "Trabzon", "district": None, "lat": 40.9600, "lon": 39.7178},
    {"name": "Akçaabat", "province": "Trabzon", "district": "Akçaabat", "lat": 41.0167, "lon": 39.5667},
    {"name": "Vakfıkebir", "province": "Trabzon", "district": "Vakfıkebir", "lat": 41.0500, "lon": 39.2833},
    {"name": "Of", "province": "Trabzon", "district": "Of", "lat": 40.9433, "lon": 40.2589},
    
    # TUNCELİ
    {"name": "Tunceli", "province": "Tunceli", "district": None, "lat": 39.1079, "lon": 39.5401},
    {"name": "Pertek", "province": "Tunceli", "district": "Pertek", "lat": 38.8667, "lon": 39.3167},
    {"name": "Hozat", "province": "Tunceli", "district": "Hozat", "lat": 39.2167, "lon": 39.2167},
    
    # UŞAK
    {"name": "Uşak", "province": "Uşak", "district": None, "lat": 38.6823, "lon": 29.4082},
    {"name": "Banaz", "province": "Uşak", "district": "Banaz", "lat": 38.7333, "lon": 29.7500},
    {"name": "Eşme", "province": "Uşak", "district": "Eşme", "lat": 38.4000, "lon": 28.9667},
    
    # VAN
    {"name": "Van", "province": "Van", "district": None, "lat": 38.4891, "lon": 43.4089},
    {"name": "Erciş", "province": "Van", "district": "Erciş", "lat": 39.0167, "lon": 43.3667},
    {"name": "Başkale", "province": "Van", "district": "Başkale", "lat": 38.0500, "lon": 44.0167},
    {"name": "Özalp", "province": "Van", "district": "Özalp", "lat": 38.6667, "lon": 43.9833},
    
    # YALOVA
    {"name": "Yalova", "province": "Yalova", "district": None, "lat": 40.6500, "lon": 29.2667},
    {"name": "Çınarcık", "province": "Yalova", "district": "Çınarcık", "lat": 40.6333, "lon": 29.1167},
    {"name": "Çiftlikköy", "province": "Yalova", "district": "Çiftlikköy", "lat": 40.6667, "lon": 29.3167},
    {"name": "Altınova", "province": "Yalova", "district": "Altınova", "lat": 40.6833, "lon": 29.5167},
    
    # YOZGAT
    {"name": "Yozgat", "province": "Yozgat", "district": None, "lat": 39.8200, "lon": 34.8147},
    {"name": "Sorgun", "province": "Yozgat", "district": "Sorgun", "lat": 39.8000, "lon": 35.1833},
    {"name": "Boğazlıyan", "province": "Yozgat", "district": "Boğazlıyan", "lat": 39.1922, "lon": 35.2469},
    
    # ZONGULDAK
    {"name": "Zonguldak", "province": "Zonguldak", "district": None, "lat": 41.4200, "lon": 31.7987},
    {"name": "Ereğli", "province": "Zonguldak", "district": "Ereğli", "lat": 41.2833, "lon": 31.4167},
    {"name": "Çaycuma", "province": "Zonguldak", "district": "Çaycuma", "lat": 41.4333, "lon": 32.0833},
    {"name": "Devrek", "province": "Zonguldak", "district": "Devrek", "lat": 41.2167, "lon": 31.9500},
    
    # AKSARAY
    {"name": "Aksaray", "province": "Aksaray", "district": None, "lat": 38.3687, "lon": 34.0370},
    {"name": "Ortaköy", "province": "Aksaray", "district": "Ortaköy", "lat": 38.7333, "lon": 34.0167},
    {"name": "Güzelyurt", "province": "Aksaray", "district": "Güzelyurt", "lat": 38.2667, "lon": 34.3667},
    
    # BAYBURT
    {"name": "Bayburt", "province": "Bayburt", "district": None, "lat": 40.2552, "lon": 40.2249},
    {"name": "Demirözü", "province": "Bayburt", "district": "Demirözü", "lat": 40.1667, "lon": 39.8833},
    
    # KARAMAN
    {"name": "Karaman", "province": "Karaman", "district": None, "lat": 37.1759, "lon": 33.2287},
    {"name": "Ermenek", "province": "Karaman", "district": "Ermenek", "lat": 36.6372, "lon": 32.8908},
    {"name": "Ayrancı", "province": "Karaman", "district": "Ayrancı", "lat": 37.2572, "lon": 33.6408},
    
    # KIRIKKALE
    {"name": "Kırıkkale", "province": "Kırıkkale", "district": None, "lat": 39.8468, "lon": 33.5153},
    {"name": "Keskin", "province": "Kırıkkale", "district": "Keskin", "lat": 39.6667, "lon": 33.6167},
    {"name": "Delice", "province": "Kırıkkale", "district": "Delice", "lat": 40.0500, "lon": 34.0500},
    
    # BATMAN
    {"name": "Batman", "province": "Batman", "district": None, "lat": 37.8812, "lon": 41.1351},
    {"name": "Kozluk", "province": "Batman", "district": "Kozluk", "lat": 38.1939, "lon": 41.4856},
    {"name": "Beşiri", "province": "Batman", "district": "Beşiri", "lat": 37.9333, "lon": 41.2667},
    
    # BARTIN
    {"name": "Bartın", "province": "Bartın", "district": None, "lat": 41.6000, "lon": 32.3375},
    {"name": "Amasra", "province": "Bartın", "district": "Amasra", "lat": 41.7500, "lon": 32.3833},
    {"name": "Ulus", "province": "Bartın", "district": "Ulus", "lat": 41.5833, "lon": 32.6333},
    
    # ARDAHAN
    {"name": "Ardahan", "province": "Ardahan", "district": None, "lat": 41.1105, "lon": 42.7022},
    {"name": "Göle", "province": "Ardahan", "district": "Göle", "lat": 40.7833, "lon": 42.6167},
    {"name": "Çıldır", "province": "Ardahan", "district": "Çıldır", "lat": 41.1333, "lon": 43.1333},
    
    # IĞDIR
    {"name": "Iğdır", "province": "Iğdır", "district": None, "lat": 39.9167, "lon": 44.0333},
    {"name": "Tuzluca", "province": "Iğdır", "district": "Tuzluca", "lat": 40.0500, "lon": 43.6500},
    
    # KİLİS
    {"name": "Kilis", "province": "Kilis", "district": None, "lat": 36.7184, "lon": 37.1212},
    {"name": "Elbeyli", "province": "Kilis", "district": "Elbeyli", "lat": 36.6667, "lon": 37.5333},
    
    # DÜZCE
    {"name": "Düzce", "province": "Düzce", "district": None, "lat": 40.8438, "lon": 31.1565},
    {"name": "Akçakoca", "province": "Düzce", "district": "Akçakoca", "lat": 41.0858, "lon": 31.1181},
    {"name": "Gölyaka", "province": "Düzce", "district": "Gölyaka", "lat": 40.7833, "lon": 31.0333},
    
    # KARABÜK
    {"name": "Safranbolu", "province": "Karabük", "district": "Safranbolu", "lat": 41.2500, "lon": 32.6833},
    {"name": "Karabük Merkez", "province": "Karabük", "district": None, "lat": 41.2061, "lon": 32.6204},
    {"name": "Yenice", "province": "Karabük", "district": "Yenice", "lat": 41.2000, "lon": 32.3500},
]

def get_city_coordinates():
    """İl merkezi ismi -> (lat, lon) sözlüğü döndürür (sadece il merkezleri)."""
    return {city["province"]: (city["lat"], city["lon"]) for city in TURKEY_CITIES if city["district"] is None}

def get_all_locations():
    """Tüm il ve ilçe kayıtlarını liste olarak döndürür."""
    return TURKEY_CITIES

def get_location_by_name(name: str):
    """İsim üzerinden (İlçe veya İl) lokasyon verisini döndürür."""
    return next((loc for loc in TURKEY_CITIES if loc["name"].lower() == name.lower()), None)