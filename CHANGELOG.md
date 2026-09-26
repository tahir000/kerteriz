# Değişiklik günlüğü

## 0.8.0 — Eylül 2026

Yayına hazırlık sürümü. Kişisel sabitler koddan çıktı, kullanıcının seçimi
oldu; mağaza için gereken belgeler yazıldı.

**Ayarlar**

- Yaş artık ayarlardan giriliyor. Nabız bölgeleri ve dolayısıyla günlük yük
  buna bağlı (Tanaka: 208 - 0,7 x yaş). 0.7.0'a kadar `lib/config.dart`
  içinde 30 yazıyordu: kendi telefonunda doğru, başkasının telefonunda yanlış
- Günlük hedefler de ayarlardan: su hedefi, su porsiyonu, adım, toplam kalori,
  aktif kalori, mesafe. Hepsi eksi/artı düğmeleriyle, klavye olmadan
- Yaş değişince veri yeniden işleniyor (son dokunuştan bir saniye sonra, tek
  okuma). Hedef değişince yalnızca widget köprüsü tazeleniyor: hedefler
  skorlara girmiyor, yeniden okumaya gerek yok
- Seçimler `kerteriz_ayarlar.json` dosyasına yazılıyor. Yazımlar sıraya
  alınıyor: hızlı dokunuşlarda iki yazım çakışıp dosyayı bozuyordu

**Widget'lar hedefi çalışma anında okuyor**

- Hedefler eskiden derlemeye gömülüydü: `patch_native.py` kurulumda
  `lib/config.dart` içindeki sayıları Kotlin sabitlerinin üstüne yazıyordu.
  Artık `kerteriz_ozet.json` içindeki `hedefler` nesnesiyle taşınıyorlar
- Yeni `AyarOkuyucu.kt` bu nesneyi okuyor; dosya yoksa (uygulama hiç
  açılmadan widget eklendiyse) gömülü varsayılana düşüyor
- Su widget'ındaki ölü `SharedPreferences` yolu kaldırıldı: hiçbir yerde
  yazılmıyordu

**Yayın belgeleri**

- `docs/index.html` — iki dilli gizlilik politikası sayfası, tek dosya, dış
  bağımlılığı yok. GitHub Pages ile yayınlanacak
- `docs/MAGAZA.md` — Play Store metinleri: iki dilde kısa ve uzun açıklama,
  sürüm notları, karakter sayıları
- `docs/YAYIN.md` yeniden yazıldı: API 36 şartı, imzalama, GitHub Pages
  kurulumu, her izin için sağlık beyanı gerekçesi, ekran görüntüsü ve özellik
  grafiği rehberi, 12 kişi / 14 gün kapalı test kuralı

**Düzeltmeler**

- Ayarlardaki sayı sütunu, sistem yazı ölçeği büyükken beş haneli hedefi
  taşırıyordu

## 0.7.0 — Eylül 2026

Ayarlar ekranı, parmakla sekme geçişi, canlanan alt menü, tek seferlik
açılış animasyonu.

**Ayarlar**

- Tema seçimi Veri sekmesinden çıkıp kendi ekranına taşındı. Her ekranın
  başlığının sağındaki düğmeden açılıyor, yani uygulamanın neresinde olursan
  ol bir dokunuş uzakta
- Ekranda görünüm tercihi (Sistem / Açık / Koyu), sürüm ve gizlilik notu var

**Gezinme**

- Sekmeler arasında parmakla sağa sola kaydırarak geçiliyor. `IndexedStack`
  yerine `PageView`: geçişin yönü ve hızı artık parmağın kendisi. Alt menü
  ile kaydırma aynı denetleyiciyi paylaşıyor, hangisiyle geçilirse geçilsin
  öteki takip ediyor
- Kaydırma konumu `PageStorageKey` ile saklanıyor
- Alt menü elde yazıldı (`NavigationBar` gitti): seçili simgenin arkasında
  genişleyen bir kapsül var, dokunulan simge zıplayıp yerine oturuyor.
  Zıplama parmakla kaydırarak gelindiğinde de oynuyor, çünkü tetikleyen şey
  dokunuş değil seçili olma anı

**Açılış**

- Simge artık bir kez doluyor ve okuma bitene kadar dolu halde bekliyor.
  Sürekli dolup boşalan halka "hiç ilerlemiyor" hissi veriyordu. Bekleyişi
  anlatan tek hareket yeşil noktanın çevresinde gidip gelen soluk halka

## 0.6.0 — Eylül 2026

Gece modu, yönlü sekme geçişi, markalı açılış ekranı ve uyku haritasındaki
taşma düzeltmesi.

**Gece modu**

- `K` sınıfındaki bütün renkler, yazı biçimleri ve gölgeler artık `static get`:
  aynı adlar `K.koyu` bayrağına göre iki farklı palet döndürüyor. Ölçü
  jetonları (boşluk, yarıçap) temadan bağımsız olduğu için `const` kaldı
- Koyu palet sıfırdan dengelendi: zemin `#0E0F12`, kart `#1A1C21`. Kartı
  zeminden ayıran şey artık gölge değil, yüzeyin biraz daha açık olması
- Seviye renkleri (yeşil / turuncu / kırmızı) koyu zeminde okunacak şekilde
  açıldı. Renk süs değil, veriyi okuma anahtarı: iki palette de ayırt edilmeli
- Veri sekmesinde **Sistem / Açık / Koyu** seçicisi. Seçim
  `kerteriz_ayarlar.json` dosyasına yazılıyor, uygulamayı kapatıp açınca
  korunuyor. "Sistem" seçiliyken telefonun gece modu izleniyor ve cihaz
  teması değişince uygulama anında dönüyor
- Tercih ilk çerçeveden önce okunuyor: uygulama açık temayla parlayıp sonra
  koyuya dönmüyor
- Durum çubuğu ve gezinme çubuğu simgeleri zeminle birlikte ters çevriliyor

**Açılış ekranı**

- Dönen çember yerine Kerteriz simgesinin kendisi: koyu yuvarlak kare,
  içinde altı açık beyaz halka. Halka sol bacaktan başlayıp saat yönünde
  doluyor, yeşil nokta da dolum oraya vardığında beliriyor
- Okuma bitince simge yerini içeriğe kısa bir açılmayla bırakıyor

**Hareket**

- Sekme geçişi artık yönlü: sağdaki sekmeye giderken sayfa sağdan, soldakine
  dönerken soldan kayarak geliyor. Yön animasyon başlarken donduruluyor ki
  geçiş sürerken sekme değişince sayfa ortada zıplamasın

**Düzeltmeler**

- Uyku düzeni haritasındaki bantlar kartın dışına taşıyordu: başlangıç ve
  genişlik ayrı ayrı kırpılıyordu, ikisi de tek tek sınırda kalsa bile
  toplamı tuvali aşabiliyordu. Bant artık kalan genişliğe sığdırılıyor,
  üstüne bir de `ClipRect` kondu
- Sabit beyaz renkler (çizgi grafiğinin uç halesi, bölge ölçerin işaretçi
  çerçevesi, paylaş düğmesinin simgesi) kart jetonuna bağlandı: koyu temada
  beyaz üstünde beyaz kalıyorlardı

## 0.5.0 — Eylül 2026

Görsel dil MagicOS'a yaklaştırıldı, uygulamaya hareket ve derinlik eklendi.

**Yüzey**

- Sayfa zemini artık gri, içerik beyaz kartlarda. Her ölçüm satırı kendi
  kartında; grafikler, yay göstergeleri ve not blokları da kart
- Büyük köşe yarıçapı, kapsül biçimli rozetler, çok yumuşak geniş gölge
- Aksan `#1668E3`, başlıklar daha kalın, sayılar tablo hizalı
- Seviye renkleri korundu ve gri zemine göre yeniden dengelendi

**Hareket**

- Ekranlar kademeli süzülerek giriyor (10. öğeden sonra gecikme sabitleniyor
  ki uzun listelerin sonu geç gelmesin)
- Yay göstergesindeki sayı yayla birlikte sıfırdan sayıyor
- Sütun grafikleri tabandan büyüyerek, çizgi grafikleri soldan sağa çiziliyor
- Sekme değişimi yumuşak geçişle; IndexedStack korundu, kaydırma konumu ve
  ekran durumu kaybolmuyor
- Dokunulan satır hafifçe küçülüyor (dalga efekti beyaz kartta kirli duruyor)

**Derinlik**

- Kaydırınca üstte kompakt başlık çubuğu beliriyor, sekme değişince sıfırlanıyor
- Alt gezinme çubuğu zeminden ayrılan beyaz yüzey

## 0.4.2 — Eylül 2026

**Açılışta ölmenin sebebi bulundu: nabız.** Açılış izi son satır olarak
`tip okunuyor: HEART_RATE` gösterdi.

- Ham nabız 5 saniyede bir örnekleniyor: 90 gün yaklaşık 1,5 milyon kayıt
  demek. Hepsini tek istekte almak belleği taşırıyor ve işletim sistemi
  süreci öldürüyordu. Dart tarafında hiçbir hata görünmüyordu çünkü süreç
  ölüyordu, istisna fırlamıyordu
- Nabız artık **iki günlük pencerelerle** okunuyor ve her pencere okunur
  okunmaz dakikalık ortalamalara indirgenip ham kayıtlar bırakılıyor.
  Bellekte kalan şey 90 gün x 1440 dakika, yani birkaç yüz kilobayt
- Nabız bölgeleri artık örnekler arası boşluk tahminiyle değil, veri olan
  her dakikanın ortalamasıyla hesaplanıyor: hem daha doğru hem sabit bellek
- Her pencere açılış izine yazılıyor, ilerleme görünür

## 0.4.1 — Eylül 2026

- **Derleme hatası düzeltildi:** `points` listesi `final` tanımlanmıştı ama
  `removeDuplicates` sonucuyla yeniden atanıyordu. 0.4.0 derlenmiyordu.

## 0.4.0 — Eylül 2026

Uygulama açılışta ölüyordu ve sebebi hiçbir yerde görünmüyordu. Artık kendisi
söylüyor.

- **Açılış izi** (`lib/data/tani.dart`): her adım diske yazılıyor. İşletim
  sistemi süreci öldürdüğünde Dart tarafındaki `catch` çalışmaz, ekranda hata
  görünmez; diske yazılan iz ise kalır
- Bir önceki açılış yarıda kaldıysa uygulama **güvenli modda** açılıyor: Health
  Connect'e hiç dokunmadan izi gösteriyor, kopyalama ve paylaşma düğmeleriyle
- Health Connect tipleri artık **tek tek** okunuyor. Toplu okuma daha hızlıydı
  ama bir tip eklentiyi çökertirse hangisi olduğu anlaşılmıyordu; şimdi her
  tipin adı okunmadan önce ize yazılıyor, son satır suçluyu gösteriyor
- `Config.atlananTipler`: sorunlu bir tipi listeye yazmak onu tümden atlatıyor
- `runZonedGuarded` ve `FlutterError.onError` de ize yazıyor

## 0.3.5 — Eylül 2026

Açılış ekranında donup uygulamanın sistem tarafından öldürülmesine karşı.

- Health Connect okumalarına **zaman aşımı** eklendi: toplu okuma 40 saniye,
  tek tip okuma 12 saniye, tüm okuma 120 saniye. Health Connect tek bir tipte
  hiç yanıt vermediğinde `await` sonsuza kadar bekliyordu; açılış ekranı
  donuyor ve sistem uygulamayı kapatıyordu
- `configure`, `sdkStatus` ve izin kontrolü de zaman aşımlı. Yanıt gelmezse
  uygulama donmak yerine hata ekranına düşüyor ve "Yeniden oku" sunuyor
- Yanıt vermeyen tipler Veri sekmesinde adlarıyla listeleniyor

## 0.3.4 — Eylül 2026

- **Düzeltme (açılmama):** izin kapısı yalnızca widget'ın kullandığı mesafe ve
  kalori tipleri yüzünden kapanabiliyordu. `hasPermissions` bu iki tipi de
  arıyordu; verilmediklerinde uygulama her açılışta izin ekranını yeniden
  çağırıyor, Health Connect tekrarlanan istekleri sınırladığı için istek
  reddediliyor ve ekranda kalıcı olarak "Health Connect izinleri verilmedi"
  kalıyordu. Artık kapı yalnızca uygulamanın gerçekten okuduğu tiplere bakıyor;
  widget tipleri aynı ekranda soruluyor ama açılışı engellemiyor
- İzin isteği artık hata durumunda çekirdek tiplerle tekrar deniyor
- Veri (tanı) sekmesi filtrelenmemiş listeyi görüyor: uyku ya da nabız olmayan
  bir günde gelen solunum veya SpO2 kaydı artık sayımdan düşmüyor
- Grafiklerde iki gizli hata: bant uzunluğu eksik kontrol ediliyordu ve çok dar
  alanda çubuk genişliği `clamp` hatası fırlatabiliyordu

## 0.3.3 — Eylül 2026

Soğuk başlangıçta uydurma kırmızı uyarılar veriyordu, hepsi susturuldu.

- **Akut/kronik oran** artık 28 günlük kronik pencerede en az 14 gün gerçek yük
  yoksa gösterilmiyor. Boş günlerle dolu pencere oranı şişiriyor ve 4.00 gibi
  "riskli" sayılar çıkıyordu
- **Günlük yük göstergesi** rengini akut/kronik orandan alıyordu; oran
  güvenilir değilken 0.9'luk bir yükü kırmızı "riskli" diye boyuyordu.
  Artık o durumda nötr çiziliyor
- 28 günlük yük grafiğinin sütunları da aynı korumaya bağlandı
- `ArcGauge` seviyesiz (nötr) çizilebiliyor
- Veri sekmesine **uygulama sürümü** satırı eklendi: telefonda hangi yapının
  çalıştığı artık tahmin edilmiyor
- Kalp sekmesinde HRV ve dinlenme nabzı ölçümü yokken "NORMAL" rozeti
  basılıyordu; olmayan bir değeri iyi gibi gösteriyordu, kaldırıldı

## 0.3.2 — Eylül 2026

- **Düzeltme:** hiçbir günde uyku ya da nabız kaydı yokken skor ekranları
  bütün günlere düşüyor ve hazırlığı "0, düşük" gösteriyordu. Bu bir skor
  değil, hesaplanamamış demekti. Artık skor sekmeleri sayı yerine durumu
  söylüyor ve Veri sekmesine yönlendiriyor; Veri sekmesi her koşulda çalışıyor
- Özet widget'ı da aynı durumda boş kalıyor (zaten öyleydi), artık uygulamayla
  tutarlı

## 0.3.1 — Eylül 2026

- **Düzeltme:** özet widget'ı ana ekrana eklenemiyordu. Düzendeki kılcal ayraç
  düz bir `View` idi; RemoteViews yalnızca `@RemoteView` işaretli sınıfları
  şişirebiliyor ve `android.view.View` o listede değil, bu yüzden başlatıcı
  "widget eklenemedi" diyordu. Ayraç `FrameLayout` oldu.

## 0.3.0 — Eylül 2026

Google Health'in kendi widget'ının Kerteriz karşılığı eklendi.

- **Özet widget'ı:** solda üç halka (adım, kalori, mesafe), sağda sayıların
  kendisi, altta hazırlık, uyku ve dinlenme nabzı
- Halkalar bitmap'e çizilir (`HalkaCizer`); ana ekran widget'ları yay çizemiyor
- Halka renkleri aksan mavisinin üç tonu: yeşil/turuncu/kırmızı bu uygulamada
  seviye anlamı taşıdığı için halkalarda süs olarak kullanılmıyor
- Türetilmiş skorlar için `kerteriz_ozet.json` köprüsü: uygulama her açılışta
  yazar, widget okur. Dosya bayatsa ya da içindeki gün bugün veya dün değilse
  o kutular boş gösterilir
- Her günlük toplam ayrı bir Health Connect sorgusu: izin verilmemiş tek bir
  tip yüzünden üç halkanın birden sıfırlanmasını önler
- Cihaz toplam kalori yazmıyorsa aktif kaloriye düşülür ve ölçek
  `dailyActiveCalorieGoal` hedefine göre kurulur
- Halkalara dokunmak yeniler, başka yere dokunmak uygulamayı açar: agresif pil
  yönetimi olan cihazlarda (Honor MagicOS) periyodik güncelleme atlanabiliyor
- `READ_DISTANCE` izni eklendi; mesafe ve kalori yalnızca widget için okunur,
  90 günlük okumaya girmez
- `patch_manifest.py` artık her parçayı ayrı ayrı koruyor: daha önce
  yamalanmış bir projeyi de günceller (eskiden tek kontrolle atlıyordu)
- README'ye Honor / MagicOS arka plan ayarları bölümü eklendi

## 0.2.0 — Eylül 2026

Ayrı bir uygulama olan su takibi widget'ı Kerteriz'e birleştirildi: tek uygulama,
tek paket.

- Ana ekran widget'ı: tek dokunuşla su ekler, günlük toplamı ve hedefe göre
  ilerlemeyi gösterir; sayıya dokunmak uygulamanın yazdığı son kaydı geri alır
- Su, Health Connect'e `HydrationRecord` olarak yazılır ve aynı yerden geri
  okunur — widget ile uygulama arasında ayrı veritabanı yok
- Uygulamanın ilk ve tek yazma izni: `WRITE_HYDRATION`. Başka hiçbir tipe yazılmaz
- Bugün sekmesine su bölümü: hedef ölçeği, 14 günlük eğilim
- Hidrasyon karşılaştırması: hedefi tutturulan günlerin ertesindeki hazırlık
  ortalaması ile tutturulmayanlarınki. Hazırlık skoruna ağırlıkla **girmez**
- Veri sekmesine su satırı; gizlilik politikası, Play sağlık beyanı ve README
  yazma izni eklenecek şekilde güncellendi
- `patch_native.py`: Kotlin dosyalarını kopyalar, paket adını projeye uydurur,
  `lib/config.dart`'taki su hedefi ve porsiyonu widget'a yazar, gradle
  bağımlılıklarını ekler — idempotent
- Bütün kod yorumları tam Türkçe karakterlerle yeniden yazıldı

## 0.1.0 — Eylül 2026

İlk çalışır sürüm.

- Health Connect'ten okuma: uyku evreleri, nabız, HRV, dinlenme nabzı, solunum,
  SpO2, cilt sıcaklığı, adım
- Bileşik metrikler: hazırlık, uyku skoru, uyku borcu, günlük yük (TRIMP),
  akut/kronik yük oranı, gece kardiyak toparlanma, sirkadiyen düzenlilik (SRI)
- Dört ekran (Bugün, Uyku, Yük, Kalp) ve Health Connect tanı ekranı (Veri)
- Eksik girdide ağırlıkların yeniden dağıtılması
- Dinlenme nabzı kaydı gelmiyorsa gece nabız serisinden türetme
- İki dil: Türkçe ve İngilizce
- 90 günlük ham + türetilmiş veriyi JSON olarak dışa aktarma
