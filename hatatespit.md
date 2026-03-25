Harita kullanırken il veya ilçe seçtiğimiz zaman eğer o bölgede bir pin bulunuyorsa otomatik olarak o pin'i açıyor. Bu da her ilçeye sadece 1 adet pin eklenebilmesine neden oluyor. 
Merhaba! Öğrendiğim üzere konsoldaki null mesajları ve Image "toll_booth" uyarıları harita stiline bağlı olaylar.

1. Image "toll_booth" could not be loaded mesajlarının sebebi: Kullandığınız harita stili (örneğin OpenFreeMap Liberty veya Carto), içindeki POI (Points of Interest) katmanlarında toll_booth, gate, atm gibi ufak simgeleri haritada göstermeye çalışıyor. Ancak web üzerinden çektiğiniz stil paketinin "sprite sheet" (simge dosyası) içinde bu grafikler bulunmuyor. MapLibre GL JS de eksik olan her ikon için saniyede onlarca kez bu uyarıyı fırlatarak styleimagemissing olayını (event) tetikliyor.

2. null yazmasının sebebi: Flutter uygulamanızda kullandığınız dart harita eklentisi (maplibre paketi), haritadaki bu olay güncellemeleri geldiğinde eksik parametre alan bazı iç olay dinleyicisi kodlarına sahip olduğundan konsola null basıyor gibi görünüyor. Arka arkaya uyarılar (null mesajları) genellikle bu grafik eksikliğinden tetiklenir.

Çözüm Önerisi: Bu, uygulamanın çalışmasını bozan ciddi bir hata değil; ağırlıklı olarak konsol kirliliğinden ibaret. Dilerseniz index.html dosyanıza ufak bir kod eklemesi yapabilirim. Harita, MapLibre motoruna bir eksik simge uyarısı verip hata fırlattığı anda (styleimagemissing event'i sırasında), bu duruma araya girip haritaya 1x1 piksellik gizli, sahte bir ikon yerleştirirsem hata tamamen bastırılmış olur. Bu sayede hem 'Image ... could not be loaded' hataları gider hem de rastgele 'null' atışlarının önüne geçilebilir.

Bu konsol kirliliği sorununu gidermek için bu çözümü uygulamamı ister misiniz?
Harita kümelemeyi açtım, haritadaki pinler gözükmemeye başladı. "Detaylı harita" moduna gerçekleşti bu. bu harita modunda  pinler gözükmüyor
