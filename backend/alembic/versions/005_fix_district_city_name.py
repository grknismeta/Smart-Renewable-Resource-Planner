"""fix district city_name to use province name

İlçe kayıtlarında city_name, ilçenin kendi adı yerine ilin adını saklamalıdır.
Böylece district-summary sorgusu city_name == il_adı ile çalışabilir.

Revision ID: 005_fix_district_city_name
Revises: 004_add_district_name
Create Date: 2026-03-21

"""
from alembic import op
import sqlalchemy as sa

revision = '005_fix_district_city_name'
down_revision = '004_add_district_name'
branch_labels = None
depends_on = None


# constants.py'deki tüm ilçe kayıtları: (eski_city_name, yeni_city_name)
# Sadece district_name IS NOT NULL olan kayıtları güncelliyoruz.
_DISTRICT_REMAP = [
    # Adana
    ("Aladağ", "Adana"), ("Ceyhan", "Adana"), ("Feke", "Adana"),
    ("Karaisali", "Adana"), ("Karataş", "Adana"), ("Kozan", "Adana"),
    ("Pozantı", "Adana"), ("Saimbeyli", "Adana"), ("Seyhan", "Adana"),
    ("Tufanbeyli", "Adana"), ("Yumurtalık", "Adana"), ("Yüreğir", "Adana"),
    ("İmamoğlu", "Adana"),
    # Adıyaman
    ("Besni", "Adiyaman"), ("Gerger", "Adiyaman"), ("Gölbaşı", "Adiyaman"),
    ("Kahta", "Adiyaman"), ("Samsat", "Adiyaman"), ("Sincik", "Adiyaman"),
    ("Tut", "Adiyaman"), ("Çelikhan", "Adiyaman"),
    # Afyon
    ("Bayat", "Afyon"), ("Başmakçı", "Afyon"), ("Bolvadin", "Afyon"),
    ("Dazkırı", "Afyon"), ("Dinar", "Afyon"), ("Emirdağ", "Afyon"),
    ("Evciler", "Afyon"), ("Hocalar", "Afyon"), ("İhsaniye", "Afyon"),
    ("İscehisar", "Afyon"), ("Kızılören", "Afyon"), ("Sandıklı", "Afyon"),
    ("Sinanpaşa", "Afyon"), ("Sultandağı", "Afyon"), ("Şuhut", "Afyon"),
    # Ağrı
    ("Diyadin", "Agri"), ("Doğubayazıt", "Agri"), ("Eleşkirt", "Agri"),
    ("Hamur", "Agri"), ("Patnos", "Agri"), ("Taşlıçay", "Agri"),
    ("Tutak", "Agri"),
    # Aksaray
    ("Ağaçören", "Aksaray"), ("Eskil", "Aksaray"), ("Gülağaç", "Aksaray"),
    ("Güzelyurt", "Aksaray"), ("Ortaköy", "Aksaray"), ("Sarıyahşi", "Aksaray"),
    # Amasya
    ("Göynücek", "Amasya"), ("Gümüşhacıköy", "Amasya"), ("Hamamözü", "Amasya"),
    ("Merzifon", "Amasya"), ("Suluova", "Amasya"), ("Taşova", "Amasya"),
    # Ankara
    ("Ayaş", "Ankara"), ("Bala", "Ankara"), ("Beypazarı", "Ankara"),
    ("Çamlıdere", "Ankara"), ("Çankaya", "Ankara"), ("Çubuk", "Ankara"),
    ("Elmadağ", "Ankara"), ("Etimesgut", "Ankara"), ("Evren", "Ankara"),
    ("Güdül", "Ankara"), ("Haymana", "Ankara"), ("Kahramankazan", "Ankara"),
    ("Kalecik", "Ankara"), ("Keçiören", "Ankara"), ("Kızılcahamam", "Ankara"),
    ("Mamak", "Ankara"), ("Nallıhan", "Ankara"), ("Polatlı", "Ankara"),
    ("Pursaklar", "Ankara"), ("Sincan", "Ankara"), ("Şereflikoçhisar", "Ankara"),
    ("Yenimahalle", "Ankara"),
    # Antalya
    ("Akseki", "Antalya"), ("Aksu", "Antalya"), ("Alanya", "Antalya"),
    ("Demre", "Antalya"), ("Döşemealtı", "Antalya"), ("Elmalı", "Antalya"),
    ("Finike", "Antalya"), ("Gazipaşa", "Antalya"), ("Gündoğmuş", "Antalya"),
    ("İbradı", "Antalya"), ("Kaş", "Antalya"), ("Kemer", "Antalya"),
    ("Kepez", "Antalya"), ("Konyaaltı", "Antalya"), ("Korkuteli", "Antalya"),
    ("Kumluca", "Antalya"), ("Manavgat", "Antalya"), ("Muratpaşa", "Antalya"),
    ("Serik", "Antalya"),
    # Ardahan
    ("Çıldır", "Ardahan"), ("Damal", "Ardahan"), ("Göle", "Ardahan"),
    ("Hanak", "Ardahan"), ("Posof", "Ardahan"),
    # Artvin
    ("Ardanuç", "Artvin"), ("Arhavi", "Artvin"), ("Borçka", "Artvin"),
    ("Hopa", "Artvin"), ("Murgul", "Artvin"), ("Şavşat", "Artvin"),
    ("Yusufeli", "Artvin"),
    # Aydın
    ("Bozdoğan", "Aydin"), ("Buharkent", "Aydin"), ("Çine", "Aydin"),
    ("Didim", "Aydin"), ("Efeler", "Aydin"), ("Germencik", "Aydin"),
    ("İncirliova", "Aydin"), ("Karacasu", "Aydin"), ("Karpuzlu", "Aydin"),
    ("Koçarlı", "Aydin"), ("Köşk", "Aydin"), ("Kuşadası", "Aydin"),
    ("Kuyucak", "Aydin"), ("Nazilli", "Aydin"), ("Söke", "Aydin"),
    ("Sultanhisar", "Aydin"), ("Yenipazar", "Aydin"),
    # Balıkesir
    ("Altıeylül", "Balikesir"), ("Ayvalık", "Balikesir"), ("Balya", "Balikesir"),
    ("Bandırma", "Balikesir"), ("Bigadiç", "Balikesir"), ("Burhaniye", "Balikesir"),
    ("Dursunbey", "Balikesir"), ("Edremit", "Balikesir"), ("Erdek", "Balikesir"),
    ("Gömeç", "Balikesir"), ("Gönen", "Balikesir"), ("Havran", "Balikesir"),
    ("İvrindi", "Balikesir"), ("Karesi", "Balikesir"), ("Kepsut", "Balikesir"),
    ("Manyas", "Balikesir"), ("Marmara", "Balikesir"), ("Savaştepe", "Balikesir"),
    ("Sındırgı", "Balikesir"), ("Susurluk", "Balikesir"),
    # Bartın
    ("Arit", "Bartin"), ("Kurucaşile", "Bartin"), ("Ulus", "Bartin"),
    # Batman
    ("Beşiri", "Batman"), ("Gercüş", "Batman"), ("Hasankeyf", "Batman"),
    ("Kozluk", "Batman"), ("Sason", "Batman"),
    # Bayburt
    ("Aydıntepe", "Bayburt"), ("Demirözü", "Bayburt"),
    # Bilecik
    ("Bozüyük", "Bilecik"), ("Gölpazarı", "Bilecik"), ("İnhisar", "Bilecik"),
    ("Osmaneli", "Bilecik"), ("Pazaryeri", "Bilecik"), ("Söğüt", "Bilecik"),
    ("Yenipazar", "Bilecik"),
    # Bingöl
    ("Adaklı", "Bingol"), ("Genç", "Bingol"), ("Karlıova", "Bingol"),
    ("Kiğı", "Bingol"), ("Solhan", "Bingol"), ("Yayladere", "Bingol"),
    ("Yedisu", "Bingol"),
    # Bitlis
    ("Adilcevaz", "Bitlis"), ("Ahlat", "Bitlis"), ("Güroymak", "Bitlis"),
    ("Hizan", "Bitlis"), ("Mutki", "Bitlis"), ("Tatvan", "Bitlis"),
    # Bolu
    ("Dörtdivan", "Bolu"), ("Gerede", "Bolu"), ("Göynük", "Bolu"),
    ("Kıbrıscık", "Bolu"), ("Mengen", "Bolu"), ("Mudurnu", "Bolu"),
    ("Seben", "Bolu"), ("Yeniçağa", "Bolu"),
    # Burdur
    ("Ağlasun", "Burdur"), ("Altınyayla", "Burdur"), ("Bucak", "Burdur"),
    ("Çavdır", "Burdur"), ("Çeltikçi", "Burdur"), ("Gölhisar", "Burdur"),
    ("Kemer", "Burdur"), ("Tefenni", "Burdur"), ("Yeşilova", "Burdur"),
    # Bursa
    ("Büyükorhan", "Bursa"), ("Gemlik", "Bursa"), ("Gürsu", "Bursa"),
    ("Harmancık", "Bursa"), ("İnegöl", "Bursa"), ("İznik", "Bursa"),
    ("Karacabey", "Bursa"), ("Keles", "Bursa"), ("Kestel", "Bursa"),
    ("Mudanya", "Bursa"), ("Mustafakemalpaşa", "Bursa"), ("Nilüfer", "Bursa"),
    ("Orhaneli", "Bursa"), ("Orhangazi", "Bursa"), ("Osmangazi", "Bursa"),
    ("Yıldırım", "Bursa"), ("Yenişehir", "Bursa"),
    # Çanakkale
    ("Ayvacık", "Canakkale"), ("Bayramiç", "Canakkale"), ("Biga", "Canakkale"),
    ("Bozcaada", "Canakkale"), ("Çan", "Canakkale"), ("Eceabat", "Canakkale"),
    ("Ezine", "Canakkale"), ("Gelibolu", "Canakkale"), ("Gökçeada", "Canakkale"),
    ("Lapseki", "Canakkale"), ("Yenice", "Canakkale"),
    # Çankırı
    ("Atkaracalar", "Cankiri"), ("Bayramören", "Cankiri"), ("Çerkeş", "Cankiri"),
    ("Eldivan", "Cankiri"), ("Ilgaz", "Cankiri"), ("Khanköy", "Cankiri"),
    ("Korgun", "Cankiri"), ("Kurşunlu", "Cankiri"), ("Orta", "Cankiri"),
    ("Şabanözü", "Cankiri"), ("Yapraklı", "Cankiri"),
    # Çorum
    ("Alaca", "Corum"), ("Bayat", "Corum"), ("Boğazkale", "Corum"),
    ("Dodurga", "Corum"), ("İskilip", "Corum"), ("Kargı", "Corum"),
    ("Laçin", "Corum"), ("Mecitözü", "Corum"), ("Oğuzlar", "Corum"),
    ("Ortaköy", "Corum"), ("Osmancık", "Corum"), ("Sungurlu", "Corum"),
    ("Uğurludağ", "Corum"),
    # Denizli
    ("Acıpayam", "Denizli"), ("Babadağ", "Denizli"), ("Baklan", "Denizli"),
    ("Bekilli", "Denizli"), ("Beyağaç", "Denizli"), ("Bozkurt", "Denizli"),
    ("Buldan", "Denizli"), ("Çal", "Denizli"), ("Çameli", "Denizli"),
    ("Çardak", "Denizli"), ("Çivril", "Denizli"), ("Güney", "Denizli"),
    ("Honaz", "Denizli"), ("Kale", "Denizli"), ("Merkezefendi", "Denizli"),
    ("Pamukkale", "Denizli"), ("Sarayköy", "Denizli"), ("Serinhisar", "Denizli"),
    ("Tavas", "Denizli"),
    # Diyarbakır
    ("Bağlar", "Diyarbakir"), ("Bismil", "Diyarbakir"), ("Çermik", "Diyarbakir"),
    ("Çınar", "Diyarbakir"), ("Çüngüş", "Diyarbakir"), ("Dicle", "Diyarbakir"),
    ("Eğil", "Diyarbakir"), ("Ergani", "Diyarbakir"), ("Hani", "Diyarbakir"),
    ("Hazro", "Diyarbakir"), ("Kayapınar", "Diyarbakir"), ("Kocaköy", "Diyarbakir"),
    ("Kulp", "Diyarbakir"), ("Lice", "Diyarbakir"), ("Silvan", "Diyarbakir"),
    ("Sur", "Diyarbakir"), ("Yenişehir", "Diyarbakir"),
    # Düzce
    ("Akçakoca", "Duzce"), ("Cumayeri", "Duzce"), ("Çilimli", "Duzce"),
    ("Gölyaka", "Duzce"), ("Gümüşova", "Duzce"), ("Kaynaşlı", "Duzce"),
    ("Yığılca", "Duzce"),
    # Edirne
    ("Enez", "Edirne"), ("Havsa", "Edirne"), ("İpsala", "Edirne"),
    ("Keşan", "Edirne"), ("Lalapaşa", "Edirne"), ("Meriç", "Edirne"),
    ("Süloğlu", "Edirne"), ("Uzunköprü", "Edirne"),
    # Elazığ
    ("Ağın", "Elazig"), ("Alacakaya", "Elazig"), ("Arıcak", "Elazig"),
    ("Baskil", "Elazig"), ("Karakoçan", "Elazig"), ("Keban", "Elazig"),
    ("Kovancılar", "Elazig"), ("Maden", "Elazig"), ("Palu", "Elazig"),
    ("Sivrice", "Elazig"),
    # Erzincan
    ("Çayırlı", "Erzincan"), ("İliç", "Erzincan"), ("Kemah", "Erzincan"),
    ("Kemaliye", "Erzincan"), ("Otlukbeli", "Erzincan"), ("Refahiye", "Erzincan"),
    ("Tercan", "Erzincan"), ("Üzümlü", "Erzincan"),
    # Erzurum
    ("Aşkale", "Erzurum"), ("Aziziye", "Erzurum"), ("Çat", "Erzurum"),
    ("Hınıs", "Erzurum"), ("Horasan", "Erzurum"), ("İspir", "Erzurum"),
    ("Karaçoban", "Erzurum"), ("Karayazı", "Erzurum"), ("Köprüköy", "Erzurum"),
    ("Narman", "Erzurum"), ("Oltu", "Erzurum"), ("Olur", "Erzurum"),
    ("Palandöken", "Erzurum"), ("Pazaryolu", "Erzurum"), ("Şenkaya", "Erzurum"),
    ("Tekman", "Erzurum"), ("Tortum", "Erzurum"), ("Uzundere", "Erzurum"),
    ("Yakutiye", "Erzurum"),
    # Eskişehir
    ("Alpu", "Eskisehir"), ("Beylikova", "Eskisehir"), ("Çifteler", "Eskisehir"),
    ("Günyüzü", "Eskisehir"), ("Han", "Eskisehir"), ("İnönü", "Eskisehir"),
    ("Mahmudiye", "Eskisehir"), ("Mihalgazi", "Eskisehir"), ("Mihalıççık", "Eskisehir"),
    ("Odunpazarı", "Eskisehir"), ("Sarıcakaya", "Eskisehir"), ("Seyitgazi", "Eskisehir"),
    ("Sivrihisar", "Eskisehir"), ("Tepebaşı", "Eskisehir"),
    # Gaziantep
    ("Araban", "Gaziantep"), ("İslahiye", "Gaziantep"), ("Karkamış", "Gaziantep"),
    ("Nizip", "Gaziantep"), ("Nurdağı", "Gaziantep"), ("Oğuzeli", "Gaziantep"),
    ("Şahinbey", "Gaziantep"), ("Şehitkamil", "Gaziantep"), ("Yavuzeli", "Gaziantep"),
    # Giresun
    ("Alucra", "Giresun"), ("Bulancak", "Giresun"), ("Çamoluk", "Giresun"),
    ("Çanakçı", "Giresun"), ("Dereli", "Giresun"), ("Doğankent", "Giresun"),
    ("Espiye", "Giresun"), ("Eynesil", "Giresun"), ("Görele", "Giresun"),
    ("Güce", "Giresun"), ("Keşap", "Giresun"), ("Piraziz", "Giresun"),
    ("Şebinkarahisar", "Giresun"), ("Tirebolu", "Giresun"), ("Yağlıdere", "Giresun"),
    # Gümüşhane
    ("Kelkit", "Gumushane"), ("Köse", "Gumushane"), ("Kürtün", "Gumushane"),
    ("Şiran", "Gumushane"), ("Torul", "Gumushane"),
    # Hakkari
    ("Çukurca", "Hakkari"), ("Şemdinli", "Hakkari"), ("Yüksekova", "Hakkari"),
    # Hatay
    ("Altınözü", "Hatay"), ("Antakya", "Hatay"), ("Arsuz", "Hatay"),
    ("Belen", "Hatay"), ("Defne", "Hatay"), ("Dörtyol", "Hatay"),
    ("Erzin", "Hatay"), ("Hassa", "Hatay"), ("İskenderun", "Hatay"),
    ("Kırıkhan", "Hatay"), ("Kumlu", "Hatay"), ("Payas", "Hatay"),
    ("Reyhanlı", "Hatay"), ("Samandağ", "Hatay"), ("Yayladağı", "Hatay"),
    # Iğdır
    ("Aralık", "Igdir"), ("Karakoyunlu", "Igdir"), ("Tuzluca", "Igdir"),
    # Isparta
    ("Aksu", "Isparta"), ("Atabey", "Isparta"), ("Eğirdir", "Isparta"),
    ("Gelendost", "Isparta"), ("Gönen", "Isparta"), ("Keçiborlu", "Isparta"),
    ("Senirkent", "Isparta"), ("Sütçüler", "Isparta"), ("Şarkikaraağaç", "Isparta"),
    ("Uluborlu", "Isparta"), ("Yalvaç", "Isparta"), ("Yenişarbademli", "Isparta"),
    # İstanbul
    ("Adalar", "Istanbul"), ("Arnavutköy", "Istanbul"), ("Ataşehir", "Istanbul"),
    ("Avcılar", "Istanbul"), ("Bağcılar", "Istanbul"), ("Bahçelievler", "Istanbul"),
    ("Bakırköy", "Istanbul"), ("Başakşehir", "Istanbul"), ("Bayrampaşa", "Istanbul"),
    ("Beşiktaş", "Istanbul"), ("Beykoz", "Istanbul"), ("Beylikdüzü", "Istanbul"),
    ("Beyoğlu", "Istanbul"), ("Büyükçekmece", "Istanbul"), ("Çatalca", "Istanbul"),
    ("Çekmeköy", "Istanbul"), ("Esenler", "Istanbul"), ("Esenyurt", "Istanbul"),
    ("Eyüpsultan", "Istanbul"), ("Fatih", "Istanbul"), ("Gaziosmanpaşa", "Istanbul"),
    ("Güngören", "Istanbul"), ("Kadıköy", "Istanbul"), ("Kağıthane", "Istanbul"),
    ("Kartal", "Istanbul"), ("Küçükçekmece", "Istanbul"), ("Maltepe", "Istanbul"),
    ("Pendik", "Istanbul"), ("Sancaktepe", "Istanbul"), ("Sarıyer", "Istanbul"),
    ("Şile", "Istanbul"), ("Şişli", "Istanbul"), ("Silivri", "Istanbul"),
    ("Sultanbeyli", "Istanbul"), ("Sultangazi", "Istanbul"), ("Tuzla", "Istanbul"),
    ("Ümraniye", "Istanbul"), ("Üsküdar", "Istanbul"), ("Zeytinburnu", "Istanbul"),
    # İzmir
    ("Aliağa", "Izmir"), ("Balçova", "Izmir"), ("Bayındır", "Izmir"),
    ("Bayraklı", "Izmir"), ("Bergama", "Izmir"), ("Beydağ", "Izmir"),
    ("Bornova", "Izmir"), ("Buca", "Izmir"), ("Çeşme", "Izmir"),
    ("Çiğli", "Izmir"), ("Dikili", "Izmir"), ("Foça", "Izmir"),
    ("Gaziemir", "Izmir"), ("Güzelbahçe", "Izmir"), ("Karabağlar", "Izmir"),
    ("Karaburun", "Izmir"), ("Karşıyaka", "Izmir"), ("Kemalpaşa", "Izmir"),
    ("Kınık", "Izmir"), ("Kiraz", "Izmir"), ("Konak", "Izmir"),
    ("Menderes", "Izmir"), ("Menemen", "Izmir"), ("Narlıdere", "Izmir"),
    ("Ödemiş", "Izmir"), ("Seferihisar", "Izmir"), ("Selçuk", "Izmir"),
    ("Tire", "Izmir"), ("Torbalı", "Izmir"), ("Urla", "Izmir"),
    # Kahramanmaraş
    ("Afşin", "Kahramanmaras"), ("Andırın", "Kahramanmaras"), ("Çağlayancerit", "Kahramanmaras"),
    ("Dulkadiroğlu", "Kahramanmaras"), ("Ekinözü", "Kahramanmaras"), ("Elbistan", "Kahramanmaras"),
    ("Göksun", "Kahramanmaras"), ("Nurhak", "Kahramanmaras"), ("Onikişubat", "Kahramanmaras"),
    ("Pazarcık", "Kahramanmaras"), ("Türkoğlu", "Kahramanmaras"),
    # Karabük
    ("Eflani", "Karabuk"), ("Eskipazar", "Karabuk"), ("Ovacık", "Karabuk"),
    ("Safranbolu", "Karabuk"), ("Yenice", "Karabuk"),
    # Karaman
    ("Ayrancı", "Karaman"), ("Başyayla", "Karaman"), ("Ermenek", "Karaman"),
    ("Kazımkarabekir", "Karaman"), ("Sarıveliler", "Karaman"),
    # Kars
    ("Akyaka", "Kars"), ("Arpaçay", "Kars"), ("Digor", "Kars"),
    ("Kağızman", "Kars"), ("Sarıkamış", "Kars"), ("Selim", "Kars"),
    ("Susuz", "Kars"),
    # Kastamonu
    ("Abana", "Kastamonu"), ("Ağlı", "Kastamonu"), ("Araç", "Kastamonu"),
    ("Azdavay", "Kastamonu"), ("Bozkurt", "Kastamonu"), ("Cide", "Kastamonu"),
    ("Çatalzeytin", "Kastamonu"), ("Daday", "Kastamonu"), ("Devrekani", "Kastamonu"),
    ("Doğanyurt", "Kastamonu"), ("Hanönü", "Kastamonu"), ("İhsangazi", "Kastamonu"),
    ("İnebolu", "Kastamonu"), ("Küre", "Kastamonu"), ("Pınarbaşı", "Kastamonu"),
    ("Seydiler", "Kastamonu"), ("Şenpazar", "Kastamonu"), ("Taşköprü", "Kastamonu"),
    ("Tosya", "Kastamonu"),
    # Kayseri
    ("Akkışla", "Kayseri"), ("Bünyan", "Kayseri"), ("Develi", "Kayseri"),
    ("Felahiye", "Kayseri"), ("Hacılar", "Kayseri"), ("İncesu", "Kayseri"),
    ("Kocasinan", "Kayseri"), ("Melikgazi", "Kayseri"), ("Özvatan", "Kayseri"),
    ("Pınarbaşı", "Kayseri"), ("Sarıoğlan", "Kayseri"), ("Sarız", "Kayseri"),
    ("Talas", "Kayseri"), ("Tomarza", "Kayseri"), ("Yahyalı", "Kayseri"),
    ("Yeşilhisar", "Kayseri"),
    # Kırıkkale
    ("Bahşili", "Kirikkale"), ("Balışeyh", "Kirikkale"), ("Çelebi", "Kirikkale"),
    ("Delice", "Kirikkale"), ("Karakeçili", "Kirikkale"), ("Keskin", "Kirikkale"),
    ("Sulakyurt", "Kirikkale"), ("Yahşihan", "Kirikkale"),
    # Kırklareli
    ("Babaeski", "Kirklareli"), ("Demirköy", "Kirklareli"), ("Kofçaz", "Kirklareli"),
    ("Lüleburgaz", "Kirklareli"), ("Pehlivanköy", "Kirklareli"), ("Pınarhisar", "Kirklareli"),
    ("Vize", "Kirklareli"),
    # Kırşehir
    ("Akçakent", "Kirsehir"), ("Akpınar", "Kirsehir"), ("Boztepe", "Kirsehir"),
    ("Çiçekdağı", "Kirsehir"), ("Kaman", "Kirsehir"), ("Mucur", "Kirsehir"),
    # Kilis
    ("Elbeyli", "Kilis"), ("Musabeyli", "Kilis"), ("Polateli", "Kilis"),
    # Kocaeli
    ("Başiskele", "Kocaeli"), ("Çayırova", "Kocaeli"), ("Darıca", "Kocaeli"),
    ("Derince", "Kocaeli"), ("Dilovası", "Kocaeli"), ("Gebze", "Kocaeli"),
    ("Gölcük", "Kocaeli"), ("İzmit", "Kocaeli"), ("Kandıra", "Kocaeli"),
    ("Karamürsel", "Kocaeli"), ("Kartepe", "Kocaeli"), ("Körfez", "Kocaeli"),
    # Konya
    ("Ahırlı", "Konya"), ("Akören", "Konya"), ("Akşehir", "Konya"),
    ("Altınekin", "Konya"), ("Beyşehir", "Konya"), ("Bozkır", "Konya"),
    ("Cihanbeyli", "Konya"), ("Çeltik", "Konya"), ("Çumra", "Konya"),
    ("Derbent", "Konya"), ("Derebucak", "Konya"), ("Doğanhisar", "Konya"),
    ("Emirgazi", "Konya"), ("Ereğli", "Konya"), ("Güneysınır", "Konya"),
    ("Hadim", "Konya"), ("Halkapınar", "Konya"), ("Hüyük", "Konya"),
    ("Ilgın", "Konya"), ("Kadınhanı", "Konya"), ("Karapınar", "Konya"),
    ("Karatay", "Konya"), ("Kulu", "Konya"), ("Meram", "Konya"),
    ("Sarayönü", "Konya"), ("Selçuklu", "Konya"), ("Seydişehir", "Konya"),
    ("Taşkent", "Konya"), ("Tuzlukçu", "Konya"), ("Yalıhüyük", "Konya"),
    ("Yunak", "Konya"),
    # Kütahya
    ("Altıntaş", "Kutahya"), ("Aslanapa", "Kutahya"), ("Çavdarhisar", "Kutahya"),
    ("Domaniç", "Kutahya"), ("Dumlupınar", "Kutahya"), ("Emet", "Kutahya"),
    ("Gediz", "Kutahya"), ("Hisarcık", "Kutahya"), ("Pazarlar", "Kutahya"),
    ("Şaphane", "Kutahya"), ("Simav", "Kutahya"), ("Tavşanlı", "Kutahya"),
    # Malatya
    ("Akçadağ", "Malatya"), ("Arapgir", "Malatya"), ("Arguvan", "Malatya"),
    ("Battalgazi", "Malatya"), ("Darende", "Malatya"), ("Doğanşehir", "Malatya"),
    ("Doğanyol", "Malatya"), ("Hekimhan", "Malatya"), ("Kale", "Malatya"),
    ("Kuluncak", "Malatya"), ("Pütürge", "Malatya"), ("Yazıhan", "Malatya"),
    ("Yeşilyurt", "Malatya"),
    # Manisa
    ("Ahmetli", "Manisa"), ("Akhisar", "Manisa"), ("Alaşehir", "Manisa"),
    ("Demirci", "Manisa"), ("Gölmarmara", "Manisa"), ("Gördes", "Manisa"),
    ("Kırkağaç", "Manisa"), ("Köprübaşı", "Manisa"), ("Kula", "Manisa"),
    ("Salihli", "Manisa"), ("Sarıgöl", "Manisa"), ("Saruhanlı", "Manisa"),
    ("Selendi", "Manisa"), ("Soma", "Manisa"), ("Şehzadeler", "Manisa"),
    ("Turgutlu", "Manisa"), ("Yunusemre", "Manisa"),
    # Mardin
    ("Artuklu", "Mardin"), ("Dargeçit", "Mardin"), ("Derik", "Mardin"),
    ("Kızıltepe", "Mardin"), ("Mazıdağı", "Mardin"), ("Midyat", "Mardin"),
    ("Nusaybin", "Mardin"), ("Ömerli", "Mardin"), ("Savur", "Mardin"),
    ("Yeşilli", "Mardin"),
    # Mersin
    ("Akdeniz", "Mersin"), ("Anamur", "Mersin"), ("Aydıncık", "Mersin"),
    ("Bozyazı", "Mersin"), ("Çamlıyayla", "Mersin"), ("Erdemli", "Mersin"),
    ("Gülnar", "Mersin"), ("Mezitli", "Mersin"), ("Mut", "Mersin"),
    ("Silifke", "Mersin"), ("Tarsus", "Mersin"), ("Toroslar", "Mersin"),
    ("Yenişehir", "Mersin"),
    # Muğla
    ("Bodrum", "Mugla"), ("Dalaman", "Mugla"), ("Datça", "Mugla"),
    ("Fethiye", "Mugla"), ("Kavaklıdere", "Mugla"), ("Köyceğiz", "Mugla"),
    ("Marmaris", "Mugla"), ("Menteşe", "Mugla"), ("Milas", "Mugla"),
    ("Ortaca", "Mugla"), ("Seydikemer", "Mugla"), ("Ula", "Mugla"),
    ("Yatağan", "Mugla"),
    # Muş
    ("Bulanık", "Mus"), ("Hasköy", "Mus"), ("Korkut", "Mus"), ("Malazgirt", "Mus"),
    # Nevşehir
    ("Acıgöl", "Nevsehir"), ("Avanos", "Nevsehir"), ("Derinkuyu", "Nevsehir"),
    ("Gülşehir", "Nevsehir"), ("Hacıbektaş", "Nevsehir"), ("Kozaklı", "Nevsehir"),
    ("Ürgüp", "Nevsehir"),
    # Niğde
    ("Altunhisar", "Nigde"), ("Bor", "Nigde"), ("Çamardı", "Nigde"),
    ("Çiftlik", "Nigde"), ("Ulukışla", "Nigde"),
    # Ordu
    ("Akkuş", "Ordu"), ("Altınordu", "Ordu"), ("Aybastı", "Ordu"),
    ("Çamaş", "Ordu"), ("Çatalpınar", "Ordu"), ("Çaybaşı", "Ordu"),
    ("Fatsa", "Ordu"), ("Gölköy", "Ordu"), ("Gülyalı", "Ordu"),
    ("Gürgentepe", "Ordu"), ("İkizce", "Ordu"), ("Kabadüz", "Ordu"),
    ("Kabataş", "Ordu"), ("Korgan", "Ordu"), ("Kumru", "Ordu"),
    ("Mesudiye", "Ordu"), ("Perşembe", "Ordu"), ("Ulubey", "Ordu"),
    ("Ünye", "Ordu"),
    # Osmaniye
    ("Bahçe", "Osmaniye"), ("Düziçi", "Osmaniye"), ("Hasanbeyli", "Osmaniye"),
    ("Kadirli", "Osmaniye"), ("Sumbas", "Osmaniye"), ("Toprakkale", "Osmaniye"),
    # Rize
    ("Ardeşen", "Rize"), ("Çamlıhemşin", "Rize"), ("Çayeli", "Rize"),
    ("Derepazarı", "Rize"), ("Fındıklı", "Rize"), ("Güneysu", "Rize"),
    ("Hemşin", "Rize"), ("İkizdere", "Rize"), ("İyidere", "Rize"),
    ("Kalkandere", "Rize"), ("Pazar", "Rize"),
    # Sakarya
    ("Adapazarı", "Sakarya"), ("Akyazı", "Sakarya"), ("Arifiye", "Sakarya"),
    ("Erenler", "Sakarya"), ("Ferizli", "Sakarya"), ("Geyve", "Sakarya"),
    ("Hendek", "Sakarya"), ("Karapürçek", "Sakarya"), ("Karasu", "Sakarya"),
    ("Kaynarca", "Sakarya"), ("Kocaali", "Sakarya"), ("Mithatpaşa", "Sakarya"),
    ("Pamukova", "Sakarya"), ("Sapanca", "Sakarya"), ("Serdivan", "Sakarya"),
    ("Söğütlü", "Sakarya"), ("Taraklı", "Sakarya"),
    # Samsun
    ("Alaçam", "Samsun"), ("Asarcık", "Samsun"), ("Atakum", "Samsun"),
    ("Ayvacık", "Samsun"), ("Bafra", "Samsun"), ("Canik", "Samsun"),
    ("Çarşamba", "Samsun"), ("Havza", "Samsun"), ("İlkadım", "Samsun"),
    ("Kavak", "Samsun"), ("Ladik", "Samsun"), ("Ondokuzmayıs", "Samsun"),
    ("Salıpazarı", "Samsun"), ("Tekkeköy", "Samsun"), ("Terme", "Samsun"),
    ("Vezirköprü", "Samsun"), ("Yakakent", "Samsun"),
    # Siirt
    ("Baykan", "Siirt"), ("Eruh", "Siirt"), ("Kurtalan", "Siirt"),
    ("Pervari", "Siirt"), ("Şirvan", "Siirt"), ("Tillo", "Siirt"),
    # Sinop
    ("Ayancık", "Sinop"), ("Boyabat", "Sinop"), ("Dikmen", "Sinop"),
    ("Durağan", "Sinop"), ("Erfelek", "Sinop"), ("Gerze", "Sinop"),
    ("Saraydüzü", "Sinop"), ("Türkeli", "Sinop"),
    # Sivas
    ("Akıncılar", "Sivas"), ("Altınyayla", "Sivas"), ("Divriği", "Sivas"),
    ("Doğanşar", "Sivas"), ("Gemerek", "Sivas"), ("Gölova", "Sivas"),
    ("Hafik", "Sivas"), ("İmranlı", "Sivas"), ("Kangal", "Sivas"),
    ("Koyulhisar", "Sivas"), ("Şarkışla", "Sivas"), ("Ulaş", "Sivas"),
    ("Yıldızeli", "Sivas"), ("Zara", "Sivas"),
    # Şanlıurfa
    ("Akçakale", "Sanliurfa"), ("Birecik", "Sanliurfa"), ("Bozova", "Sanliurfa"),
    ("Ceylanpınar", "Sanliurfa"), ("Eyyübiye", "Sanliurfa"), ("Halfeti", "Sanliurfa"),
    ("Haliliye", "Sanliurfa"), ("Harran", "Sanliurfa"), ("Hilvan", "Sanliurfa"),
    ("Karaköprü", "Sanliurfa"), ("Siverek", "Sanliurfa"), ("Suruç", "Sanliurfa"),
    ("Viranşehir", "Sanliurfa"),
    # Şırnak
    ("Beytüşşebap", "Sirnak"), ("Cizre", "Sirnak"), ("Güçlükonak", "Sirnak"),
    ("İdil", "Sirnak"), ("Silopi", "Sirnak"), ("Uludere", "Sirnak"),
    # Tekirdağ
    ("Çerkezköy", "Tekirdag"), ("Çorlu", "Tekirdag"), ("Ergene", "Tekirdag"),
    ("Hayrabolu", "Tekirdag"), ("Malkara", "Tekirdag"), ("Marmaraereğlisi", "Tekirdag"),
    ("Muratlı", "Tekirdag"), ("Saray", "Tekirdag"), ("Süleymanpaşa", "Tekirdag"),
    ("Şarköy", "Tekirdag"),
    # Tokat
    ("Almus", "Tokat"), ("Artova", "Tokat"), ("Başçiftlik", "Tokat"),
    ("Erbaa", "Tokat"), ("Niksar", "Tokat"), ("Pazar", "Tokat"),
    ("Reşadiye", "Tokat"), ("Sulusaray", "Tokat"), ("Turhal", "Tokat"),
    ("Yeşilyurt", "Tokat"), ("Zile", "Tokat"),
    # Trabzon
    ("Akçaabat", "Trabzon"), ("Araklı", "Trabzon"), ("Arsin", "Trabzon"),
    ("Beşikdüzü", "Trabzon"), ("Çarşıbaşı", "Trabzon"), ("Çaykara", "Trabzon"),
    ("Dernekpazarı", "Trabzon"), ("Düzköy", "Trabzon"), ("Hayrat", "Trabzon"),
    ("Köprübaşı", "Trabzon"), ("Maçka", "Trabzon"), ("Of", "Trabzon"),
    ("Ortahisar", "Trabzon"), ("Sürmene", "Trabzon"), ("Şalpazarı", "Trabzon"),
    ("Tonya", "Trabzon"), ("Vakfıkebir", "Trabzon"), ("Yomra", "Trabzon"),
    # Tunceli
    ("Çemişgezek", "Tunceli"), ("Hozat", "Tunceli"), ("Mazgirt", "Tunceli"),
    ("Nazimiye", "Tunceli"), ("Ovacık", "Tunceli"), ("Pertek", "Tunceli"),
    ("Pülümür", "Tunceli"),
    # Uşak
    ("Banaz", "Usak"), ("Eşme", "Usak"), ("Karahallı", "Usak"),
    ("Sivaslı", "Usak"), ("Ulubey", "Usak"),
    # Van
    ("Bahçesaray", "Van"), ("Başkale", "Van"), ("Çaldıran", "Van"),
    ("Çatak", "Van"), ("Edremit", "Van"), ("Erciş", "Van"),
    ("Gevaş", "Van"), ("Gürpınar", "Van"), ("İpekyolu", "Van"),
    ("Muradiye", "Van"), ("Özalp", "Van"), ("Saray", "Van"),
    ("Tuşba", "Van"),
    # Yalova
    ("Altınova", "Yalova"), ("Armutlu", "Yalova"), ("Çınarcık", "Yalova"),
    ("Çiftlikkoy", "Yalova"), ("Termal", "Yalova"),
    # Yozgat
    ("Akdağmadeni", "Yozgat"), ("Aydıncık", "Yozgat"), ("Boğazlıyan", "Yozgat"),
    ("Çandır", "Yozgat"), ("Çayıralan", "Yozgat"), ("Çekerek", "Yozgat"),
    ("Kadışehri", "Yozgat"), ("Saraykent", "Yozgat"), ("Sarıkaya", "Yozgat"),
    ("Şefaatli", "Yozgat"), ("Sorgun", "Yozgat"), ("Yerköy", "Yozgat"),
    # Zonguldak
    ("Alaplı", "Zonguldak"), ("Çaycuma", "Zonguldak"), ("Devrek", "Zonguldak"),
    ("Ereğli", "Zonguldak"), ("Gökçebey", "Zonguldak"), ("Kilimli", "Zonguldak"),
    ("Kozlu", "Zonguldak"),
]


def upgrade():
    """İlçe kayıtlarında city_name'i il adıyla güncelle."""
    conn = op.get_bind()
    for old_name, province_name in _DISTRICT_REMAP:
        conn.execute(
            sa.text(
                "UPDATE hourly_weather_data "
                "SET city_name = :province "
                "WHERE city_name = :old AND district_name IS NOT NULL"
            ),
            {"province": province_name, "old": old_name},
        )


def downgrade():
    """Geri alma: il adını tekrar ilçe adıyla değiştir."""
    conn = op.get_bind()
    for old_name, province_name in _DISTRICT_REMAP:
        conn.execute(
            sa.text(
                "UPDATE hourly_weather_data "
                "SET city_name = :old "
                "WHERE city_name = :province AND district_name = :old"
            ),
            {"province": province_name, "old": old_name},
        )
