# Kerteriz — Proje Brifingi

> Bu belge, projeyi başka bir yapay zeka asistanına devretmek için hazırlandı.
> Amacı: kod okumadan önce neyin neden böyle yapıldığını anlatmak.

---

## 1. Tek cümleyle

Google **Fitbit Air** bileklikten gelen veriyi **Health Connect** üzerinden telefonda
okuyup, ham ölçüleri bileşik sağlık metriklerine (hazırlık, uyku skoru, yük,
sirkadiyen düzenlilik) çeviren, **Flutter** ile yazılmış kişisel bir Android
uygulaması. Veri cihazdan çıkmıyor.

**Kullanıcı:** Tahir. İstanbul'da bir hukuk bürosunda çalışıyor, yazılımcı değil ama
teknik konuları takip ediyor.

---

## 2. Neden bu mimari — kritik zamanlama bilgisi

**Eski Fitbit Web API Eylül 2026'da tamamen kapandı.** İnternette bulunan hemen her
"Fitbit API" örneği, kütüphanesi ve tutorial'ı artık ölü. Yerine **Google Health API** geldi.

İki erişim yolu var:

| | A — Health Connect (seçilen) | B — Google Health API |
|---|---|---|
| Nerede çalışır | Telefonda, cihaz üzerinde | Bulut, REST |
| Onay | Yok | Restricted scope, CASA denetimi |
| Maliyet | Yok | Yayına çıkarken 500–4.500 USD |
| Kullanıcı sınırı | Yok | Doğrulanmamış uygulama 100 kullanıcı |
| Platform | Yalnızca Android | Her yer |
| Çözünürlük | Google Health ne yazarsa | ~5 saniyelik nabız dahil |

**A seçildi.** Kişisel kullanım için onay beklemeye ve ücret ödemeye gerek yok, veri
telefondan çıkmıyor, offline çalışıyor. İlerde yayına çıkılırsa B'ye taşınabilir.

**Zincir:** Fitbit Air → Google Health uygulaması → Health Connect → Kerteriz.

---

## 3. Bilinen veri kapsamı

**Gerçek veriyle doğrulandı (7 Ekim 2026, 32 gün):** HRV 31 gece, dinlenme
nabzı 32 gece (cihazın kendi kaydı, türetilmiş değil), solunum hızı 29 gece
geliyor. **Cilt sıcaklığı ve SpO2 hiç gelmiyor.** Nabız serisi, uyku evreleri ve
adım da yazılıyor. (Bu bölüm eskiden dinlenme nabzı ve solunumun gelmediğini
söylüyordu; yanlıştı.)

- **Dinlenme nabzı kaydı yoksa türetiliyor:** gecenin en düşük 30 dakikalık
  kararlı ortalaması. Şu an gerek kalmadı ama başka cihazlar için duruyor.
- **SpO2 ve cilt sıcaklığı türetilemez.** Hastalık uyarısı sıcaklık yokken
  solunum + nabız ikilisine bakıyor.
- **Şekerlemeler:** Google Health gündüz kestirmelerini de uyku evresi olarak
  yazıyor. Aynı uyku gününe düşen parçalar 60 dakikadan uzun boşlukla ayrı
  bloklara bölünüyor (`data/uyku_bloklari.dart`); en uzun blok gece, ötekiler
  yalnızca borca sayılan şekerleme. 0.11.0'dan önce hepsi tek oturumdu ve 32
  gecenin 6'sında yatakta süresi 10–20 saat görünüyordu.
- **Su alımı uygulamanın kendi ürettiği tek veridir.** Ana ekran widget'ı
  Health Connect'e yazar, uygulama aynı yerden geri okur; ayrı bir veritabanı yok.
- **Mesafe ve kalori yalnızca özet widget'ı için okunur.** Skorlara girmezler,
  90 günlük okumaya da dahil değiller; izinleri uygulama üzerinden isteniyor
  çünkü widget ayrı bir izin akışı çalıştıramaz.

Uygulamada bunun için iki mekanizma var:

1. **Zarif bozulma:** bir girdi hiç gelmezse ağırlığı ötekilere oransal dağıtılır,
   skor yine 0–100 arasında kalır (`MetricsEngine.run` içindeki `add()` bloğu).
2. **Veri kapsamı ekranı** (5. sekme): Health Connect'ten tip tip kaç kayıt geldiğini
   ve hangi metriğin hesaplanabildiğini gösterir.

---

## 4. Türetilmiş metrik sistemi

Projenin asıl değeri burada. Ham veriyi Whoop/Bevel tarzında bileşik metriklere çevirir.

### Katman 1 — normalize edilmiş sapmalar

Her ölçüm kendi **14 günlük taban çizgisine** göre z-skoruna çevrilir:

```
z      = (x - ort14) / ss14
nz(z)  = clamp(0.5 + z / 3.6, 0, 1)     # 0..1 aralığına taşıma
```

**HRV için taban çizgi `ln(x)` üzerinde kurulur** — RMSSD log-normal dağılır, ham
ortalama yanıltır. Bu ayrıntı atlanmamalı.

### Katman 2 — bileşik skorlar

**Hazırlık (0–100)**
```
hazırlık = 100 * ( 0.40*nz(z_HRV)
                 + 0.25*nz(-z_RHR)              # düşük nabız iyi, işaret ters
                 + 0.25*(uyku_skoru/100)
                 + 0.10*nz(-(z_solunum + z_sıcaklık)/2) )
```
Eksik girdi olursa ağırlıklar kalanlara oransal dağıtılır. **Taban çizgisi
henüz `Config.minBaselineNights` (7) geceden kurulmamış girdi de eksik sayılır**
(0.10.0'dan beri): eskiden z = 0 olarak "tam ortalama" diye katılıyordu ve yeni
kullanıcı ilk iki hafta hep 50 civarında bir skor görüyordu. İlk 7 gece hazırlık
yalnızca uykudan kurulur; Bugün ekranı 14. geceye kadar bir kalibrasyon kartı
gösterir. Solunum ve sıcaklıktan yalnızca biri varsa öteki sıfır z'yle
ortalamaya girmez.

**Uyku skoru (0–100)** — beş bileşenin ağırlıklı toplamı
```
süre          = clamp(uyku / ihtiyaç, 0, 1) * 100                    # %35
verim         = clamp((uyku/yatakta - 0.85) / 0.13, 0, 1) * 100      # %20
onarım        = clamp(((derin+rem)/uyku) / 0.42, 0, 1) * 100         # %25
kesintisizlik = clamp(100 - 4.5*uyanma - 0.55*uyanık_dk, 0, 100)     # %10
zamanlama     = 15 dk sapmaya kadar 100, 120 dk'da 0 (doğrusal)       # %10
                # sapma: orta nokta - son 21 gecenin MEDYANI
```

**Uyku ihtiyacı** — sabit değil, dünkü yüke göre kayar:
```
ihtiyaç = 438 dk + dünkü_yük * 2.2
```

**Uyku borcu** — son 14 gün, günde %7 sönümleme:
```
borç = SUM( max(0, ihtiyaç_j - uyku_j) * 0.93^(bugün - j) )
```

**Günlük yük (0–21)** — Banister TRIMP mantığı, log ölçek:
```
HRR      = (nabız - dinlenme) / (maks - dinlenme)     # maks = 208 - 0.7*yaş
bölgeler = [%50-60, %60-70, %70-85, %85+] HRR
ağırlık  = [1.00, 1.85, 2.90, 4.60]
ham      = SUM(bölge_dk * ağırlık) + adım * 0.0022
yük      = clamp( 6.9 * ln(1 + ham/24), 0, 21 )
```

**ACWR — akut/kronik yük oranı**
```
oran = ort(yük, son 7 gün) / ort(yük, son 28 gün)
0.80–1.30 sürdürülebilir · 0.60–1.50 sınır · dışı riskli
```

**Gece kardiyak toparlanma (0–100)** — nabzın ne kadar *ve ne kadar erken* dip yaptığı
```
düşüş = (ilk_hr - dip_hr) / ilk_hr
f_dip = dip_zamanı / gece_süresi
skor  = 100 * ( 0.55*clamp(düşüş/0.16,0,1) + 0.45*clamp((0.72-f_dip)/0.42,0,1) )
```

**SRI — Sleep Regularity Index (0–100)** — literatürdeki gerçek metrik
```
Ardışık iki günü 10 dakikalık 144 dilime böl.
Aynı dilimde aynı durumda (uyku/uyanık) olma yüzdesi, 30 gün üzerinden ortalama.
```

### Katman 3 — içgörüler

- **Hastalık erken uyarısı:** solunum z > 1.2 **ve** cilt sıcaklığı z > 1.0 **ve**
  nabız z > 0.8, son 3 günün en az 2'sinde. Üçlüsüne birlikte bakmak tek başına
  nabza bakmaktan erken uyarır.
- **Gece nabzı uyarısı** (`Insights.elevatedNightHr`): Fitbit Air solunum ve
  sıcaklık yazmadığı için üstteki üçlü hiç tetiklenemiyor. Sade sürüm: son iki
  gece takvimde ardışık, ikisinde de dinlenme nabzı z ≥ 1.5 **ve** taban
  çizginin en az 3 atım üstünde, taban çizgi en az 7 geceden kurulmuş. Mutlak
  eşik, varyansı çok düşük kişide 1 atımlık farkın alarm olmasını engeller.
  Metin teşhis koymaz; alkol, geç yemek ve yorgunluğu da sayar.
- **Haftalık özet** (`Insights.weekly`): son 7 takvim günü ile önceki 7 gün.
  Hazırlık ve uyku ortalaması, en iyi gece, borç değişimi. Haftada 4 geceden
  azsa gösterilmez. Liste filtrelenmiş olabileceği için indeksle değil tarihle
  sayar.
- **Yatma saati önerisi** (`Insights.bedtime`): ihtiyaç motorla aynı formül
  (taban + bugünkü yük x 2.2) + borcun dörtte biri (en çok 60 dk). Yatakta
  geçecek süre son 14 gecedeki kendi uyku verimine bölünür (3 geceden azsa %90).
  Kalkış saati ayarlardan, 15 dakikalık adımlarla.
- **Etiket günlüğü** (`Insights.tagEffects`, `data/etiketler.dart`): alkol, geç
  kafein, geç yemek, yoğun stres, geç antrenman. Akşamın etiketi **ertesi
  sabahın** hazırlığıyla eşleşir; 05:00'ten önce açılan uygulama hala dün
  akşamdır. Yalnızca günlüğe bakılmış akşamlar sayılır ("Hiçbiri" bunun için
  var); işaretlenmemiş akşam "alkol yoktu" demek değil. Su karşılaştırmasıyla
  aynı ilke: katsayı yok, her iki grupta en az 4 akşam, kendi verin konuşur.
  Health Connect'te karşılığı olmadığı için `kerteriz_etiketler.json` dosyasında.
- **Kardiyak toparlanma başlangıcı** 0.10.0'dan beri ilk 30 dakikanın (üç
  kova) medyanı. Tek ilk kova, yatakta telefona bakılan birkaç dakikayla şişip
  skoru 30 puana kadar yukarı itebiliyordu (`test/engine_test.dart` bunu ölçüyor).
- **Yüklenme:** ACWR > 1.45 **ve** HRV üç gündür taban çizginin altında.
- **Hidrasyon karşılaştırması** (`MetricsEngine.hydrationEffect`): su kaydı olan
  günler "hedefte" / "hedefin altında" diye ikiye ayrılır, her grubun **ertesi**
  günündeki hazırlık ortalaması karşılaştırılır. Her iki grupta da en az 4 gün
  şartı var; ayrıca eşleşen iki gün takvimde gerçekten ardışık olmalıdır.
  **Hazırlık skoruna ağırlıkla girmez** — su alımının HRV ve nabza etkisi gerçek
  ama bir katsayı rakamı verecek kadar net değil. Göstermek başka, skora katmak
  başka; burada uydurulmuş katsayı yerine kullanıcının kendi verisi konuşur.

---

## 5. Mimari ve dosya haritası

> **Depo düzeni.** İki ayrı README var, karıştırılmamalı:
> kökteki `README.md` GitHub'ın ana sayfasında görünen tanıtım sayfasıdır
> (ortalanmış logo, metrik tablosu, belge bağlantıları). Kurulum ve teknik
> notlar `docs/KURULUM.md` içindedir ve zip paketinde kökteki `README.md`
> olarak dağıtılır. Biri ötekinin üstüne kopyalanmamalı.

```
lib/
  config.dart                 motor sabitleri + tercih varsayılanları
  l10n.dart                   iki dil (tr, en), 289 anahtar
  theme.dart                  iki palet (açık/koyu), tipografi, seviye eşikleri
  data/
    ayarlar.dart              tema, yaş, kalkış saati, günlük hedefler (küçük JSON dosyası)
    etiketler.dart            etiket günlüğü: akşam başına etiketler (küçük JSON dosyası)
    hisler.dart               sabah değerlendirmesi (1-5), küçük JSON dosyası
    hatirlatici.dart          akşam ve sabah bildirimi (flutter_local_notifications), her açılışta yeniden kurulur
    onbellek.dart             gün önbelleği: açılışta diskten, tazeleme arkada
    day_record.dart           gün modeli + JSON serileştirme
    uyku_bloklari.dart        gece uykusunu şekerlemelerden ayırır
    health_repository.dart    Health Connect okuma, günlük toplama, kapsama takibi
    exporter.dart             90 günlük ham+türetilmiş veriyi JSON'a yazıp paylaşır
    ozet_yazici.dart          widget köprüsü: türetilmiş skorlar + hedefler
    tani.dart                 açılış izi (diske yazılır), güvenli mod
  metrics/
    engine.dart               taban çizgiler, z-skorları, bütün bileşik metrikler
    gun_ici.dart              gün içi stres (sakin uyanık nabza göre) ve enerji tahmini
    insights.dart             haftalık özet, yatma saati, etiket etkisi, gece nabzı uyarısı,
                              günün cümlesi (Gunluk), otomatik karşılaştırmalar (Deneyler)
test/
  engine_test.dart            motor formülleri (hazırlık, kalibrasyon, borç, yük, kardiyak)
  insights_test.dart          içgörüler ve etiket günlüğü
  uyku_bloklari_test.dart     şekerleme ayrımı
  today_screen_test.dart      ekranlar sentetik veriyle hatasız ve taşmasız çiziliyor mu
tool/
  kalibre.dart                dışa aktarılan veriyle bileşen dağılımları (eşik ayarı için)
  ui/
    shell.dart                izin akışı, yükleme, 5 sekme (PageView), alt menü
    ayarlar_ekrani.dart       görünüm, yaş, günlük hedefler, sürüm
    screens.dart              Bugün / Uyku / Yük / Kalp
    coverage_screen.dart      Veri — Health Connect tanı ekranı
    gun_ici_ekrani.dart       gün içi ayrıntı: enerji eğrisi, saatlik stres
    verin_ekrani.dart         "Senin verin ne diyor": etiket, su ve otomatik karşılaştırmalar
    widgets/kit.dart          satır, bölgeli ölçek, rozet, bölmeli seçici
    widgets/gauge.dart        yay göstergesi, mini eğilim çizgisi, giriş animasyonu
    widgets/charts.dart       CustomPainter grafikleri (harici grafik kütüphanesi yok)
    widgets/marka.dart        açılış ekranı: Kerteriz simgesi dolarak çiziliyor
native/
  kotlin/SuWidgetProvider.kt  ana ekran su widget'ı (AppWidgetProvider, RemoteViews)
  kotlin/SuKaydedici.kt       Health Connect'e su yazma / okuma / son kaydı silme
  kotlin/OzetWidgetProvider.kt  ana ekran özet widget'ı (Google Health karşılığı)
  kotlin/OzetOkuyucu.kt       günlük adım/kalori/mesafe toplamı + özet JSON
  kotlin/HalkaCizer.kt        eş merkezli halkalar: gradyan, ikinci tur, uç gölgesi
  kotlin/BugunWidgetProvider.kt  Bugün widget'ı: hazırlık + dört halka + su düğmesi
  kotlin/WidgetBoyut.kt       üç boyut sınıfı (küçük/orta/büyük); WidgetYenileyici
  kotlin/WidgetOrtak.kt       widget'ların ortak renk, niyet ve biçim yardımcıları
  kotlin/AyarOkuyucu.kt       widget hedeflerini özet dosyasından okur
  res/                        widget düzenleri, çizimleri, renkleri, metinleri
patch_manifest.py             izinler, queries, izin gerekçesi alias'ı, widget alıcısı
patch_mainactivity.py         FlutterActivity -> FlutterFragmentActivity; onStop'ta widget'ları tazeler
patch_native.py               native/ kopyalar, paketi ve config değerlerini yazar
```

**Tema tek bir bayrağa bağlı.** `K` sınıfındaki renkler, yazı biçimleri ve
gölgeler `static const` değil `static get`: hepsi `K.koyu` bayrağına bakıyor ve
gece modunda aynı adlar farklı değer döndürüyor. Bayrak `KerterizApp.build`
içinde, tercih ile cihaz parlaklığı birlikte değerlendirilerek kuruluyor.
Bunun bir bedeli var: tema jetonu içeren hiçbir ifade artık `const` olamaz.
Ölçü jetonları (boşluk, yarıçap) temadan bağımsız olduğu için `const` kaldı.

**Hedefler artık koda gömülü değil.** 0.8.0'a kadar yaş ve günlük hedefler
`lib/config.dart` içindeydi; `patch_native.py` kurulum sırasında bu sayıları
Kotlin sabitlerinin üstüne yazıyordu. Kendi telefonunda çalışan kişisel bir
yapıda bu yeterliydi, mağazadan kurulan bir uygulamada değil: nabız
bölgelerini herkes için 30 yaşa göre hesaplamak yanlış sonuç üretir. Şimdi
seçimler [Ayarlar] içinde, `kerteriz_ayarlar.json` dosyasında; hedefler ayrıca
`kerteriz_ozet.json` içindeki `hedefler` nesnesiyle Kotlin tarafına taşınıyor.
Gömülü sabitler yedek olarak duruyor: uygulama hiç açılmadan widget eklenirse
widget onlara düşüyor.

**Açılış neden hızlı.** 90 günün tamamını her açılışta Health Connect'ten
okumak dakikalar sürüyordu ve neredeyse tamamı boşa gidiyordu: altmış gün
önceki bir gece bir daha değişmiyor. `onbellek.dart` okunan günleri diske
yazıyor; açılışta önce o dosya okunuyor (ekran anında geliyor), sonra arka
planda yalnızca boşluk kadar gün tazeleniyor. Taban çizgiler ve bütün
türetilmiş ölçüler her açılışta tam listeden yeniden hesaplanıyor, yani
önbellek yalnızca ham okumayı atlıyor, hesabı değil.

Güvenilirliği iki şey sağlıyor: parmak izi (hesabı etkileyen bir şey
değişirse önbellek reddediliyor) ve boş okumayı yazmama kuralı
(`load()` hata yutup boş iskelet günlerle başarıyla dönebiliyor).

**Önemli tasarım kararı:** günler "uyanılan takvim günü"ne yazılır. Sabah 18:00'dan
önce biten uyku o güne, sonra bitenler ertesi güne. `HealthRepository._sleepDay()`.

**Gün iskeleti önceden oluşturulur** ve arama fonksiyonu `null` döner — aksi halde
akşam saatindeki tek bir ölçüm "yarın" tarihli hayalet bir kayıt üretiyordu.

**Android dosyaları üzerine yazılmaz, yamalanır.** Elle yazılmış bir
`AndroidManifest.xml`'i kopyalamak `Build failed due to use of deleted Android v1
embedding` hatasına yol açtı. `patch_manifest.py`, `patch_mainactivity.py` ve
`patch_native.py` idempotent yamalayıcılardır.

**Widget'ın ayarları `lib/config.dart`'tan gelir.** Kotlin tarafında
`VARSAYILAN_PORSIYON` ve `VARSAYILAN_HEDEF` sabitleri vardır; `patch_native.py`
kurulum sırasında bunları `waterServingMl` ve `dailyWaterGoalMl` değerleriyle
değiştirir. Tek kaynak config.dart'tır, Kotlin elle düzenlenmez. Aynı betik
Kotlin dosyalarının `package` satırını da MainActivity.kt'ninkiyle eşitler.

**Özet widget'ı ile Dart arasındaki köprü bir dosyadır.** Hazırlık, uyku skoru
ve dinlenme nabzı 14 günlük taban çizgiye dayanır; motor Dart'ta çalıştığı için
Kotlin bunları hesaplayamaz. Uygulama her okumadan sonra `kerteriz_ozet.json`
dosyasına yazıyor (`getApplicationSupportDirectory()`, Android'de
`context.filesDir`), widget oradan okuyor. MethodChannel ya da
`shared_preferences` yerine bunun seçilmesinin sebebi: MainActivity'yi
yamalamayı gerektirmiyor ve eklenti sürümlerine bağımlı değil. Dosyada hem
yazılma zamanı hem skorların ait olduğu gün var; ikisi de kontrol ediliyor,
çünkü uyku kaydı gelmeyen bir gece sonrası dosya bugün yazılsa da içindeki
skorlar birkaç gün öncesine ait olabiliyor.

**Günlük toplamlar tek tek sorulur.** Health Connect, aggregate kümesindeki tek
bir tipin izni yoksa çağrının tamamını reddediyor. Adım, mesafe ve kalori ayrı
isteklerle sorulmasaydı, "toplam kalori" iznini vermeyen bir kullanıcıda üç
halka birden sıfır görünürdü.

**Widget yayın alıcısıdır**, dolayısıyla `onReceive` dönünce süreç öldürülebilir.
Health Connect yazması ve çizim `goAsync()` ile alınan bekleyen sonuca bağlanır;
iş bitince `finish()` çağrılır. Bu olmadan dokunuşlar sessizce kayboluyordu.

---

## 6. Ortam ve bağımlılık kısıtları

Bunlar acı çekilerek öğrenildi, değiştirilmemeli:

| Kısıt | Sebep |
|---|---|
| `intl: any` | `flutter_localizations` intl'i kesin sabitler; caret sürüm çatışması üretir |
| `share_plus: ^13.3.0` | `health` → `device_info_plus 13` → `win32 ^6`; eski share_plus `win32 ^5` istiyor |
| Dart SDK ≥ 3.10 | `share_plus 13`'ün gereksinimi |
| `minSdk = 28` | Health Connect daha eskisinde çalışmıyor |
| `READ_HEALTH_DATA_HISTORY` izni | Olmadan 30 günden eski kayıt okunamaz; taban çizgiler buna bağlı |
| `FlutterFragmentActivity` | `health` paketi Android 14 için bunu şart koşuyor |
| Tek WRITE izni `WRITE_HYDRATION` | Su widget'ı için şart; başka hiçbir tipe yazılmaz, bilinçli |
| `patch_manifest.py` parça parça korumalı | Tek "zaten yamalı" kontrolü, sonradan eklenen izin ve widget'ı mevcut projeye hiç sokmuyordu |
| `connect-client:1.1.0` | Bu sürümde `Record` yapıcısında `metadata` zorunlu; `Metadata.manualEntry()` |

`share_plus 13`'te API değişti: `Share.shareXFiles(...)` yerine
`SharePlus.instance.share(ShareParams(files: [...]))`.

**Geliştirme ortamı:** macOS (MacBook Air), **VS Code** (Flutter eklentisi ile),
Android Studio yalnızca Android SDK deposu olarak kurulu, editör olarak
kullanılmıyor. Test cihazı: **Honor Magic 7** (MagicOS). Daha önce Samsung
SM-F956B (Galaxy Z Fold 6) kullanılıyordu.

**MagicOS arka planı sert kesiyor.** Widget'lar yayın alıcısıyla çalıştığı için
periyodik güncelleme atlanabiliyor. Kurulumda Optimizer > Uygulama başlatma
altında otomatik yönetim kapatılmalı, pil optimizasyonu "İzin verme" yapılmalı.
Her iki widget da elle yenilenebilir (su: düğme, özet: halkalara dokunma);
bu, bilinçli bir telafi.

---

## 7. Durum

**Çalışıyor:** Proje derleniyor, telefona kuruluyor, açılıyor. Health Connect
izinleri veriliyor, okuma yapılıyor.

**Bekleniyor:** Cihaz yeni alındı, henüz birkaç günlük veri var. Taban çizgiler için
~14 gece gerekiyor. O zamana kadar z-skorları sıfıra yakın çıkar — hata değil.

**Son eklenen:** (1) ayrı bir uygulama olan su takibi widget'ı Kerteriz'e tam
olarak birleştirildi, tek uygulama tek paket; uygulama böylece ilk ve tek yazma
iznini kazandı (`WRITE_HYDRATION`). (2) Google Health'in kendi widget'ının
karşılığı olan özet widget'ı eklendi: üç halka (adım, kalori, mesafe) ve altında
hazırlık, uyku, dinlenme nabzı. Gizlilik politikası, Play sağlık beyanı ve
README buna göre güncellendi.

**Eşik ayarı (0.11.0):** `dart run tool/kalibre.dart <dışa-aktarım.json>`
bileşen dağılımlarını yazar. İlk ayar 32 günlük gerçek veriyle yapıldı: verim
bileşeni gecelerin yarısında 100'deydi (bileklik verimi %94–97 ölçüyor),
zamanlama dörtte birinde 0'daydı; ikisi de değişti. **Bilerek değişmeyenler:**
uyku ihtiyacı tabanı (kişinin mevcut alışkanlığından ihtiyaç çıkarılamaz; az
uyuyan birine göre ayarlamak az uykuyu normal sayar), onarıcı evre hedefi
(%42 literatürdeki ortalama, kullanıcının medyanı %41), borç ve hazırlık
seviye sınırları (hazırlık zaten kişinin kendi taban çizgisine göre).

**Bugün ekranının düzeni (0.12.0):** en üstte günün cümlesi, sonra hazırlık
göstergesi, uyarılar, "Bugün için", "Bu gece" (yatış + etiketler + su), "Kendi
verin" girişi, açılır bölümler (girdiler, haftalık özet) ve 30 günlük grafik.
Ekran 20 karta yaklaşmıştı; ilke: her gün bakılan üstte, ara sıra bakılan
açılırda, açıklamalar alt sayfada.

**Widget'lar (0.13.0):** üç widget × üç boyut = dokuz düzen
(`native/res/layout/{su,ozet,bugun}_{kucuk,orta,buyuk}.xml`). Bir boyutta
olmayan görünüme yapılan `setTextViewText` RemoteViews tarafından sessizce
atlanıyor; kod bu yüzden her boyutta bütün kimlikleri yazıyor. Halka
bitmap'i üç düzen arasında paylaşılıyor (320 px, ~400 KB): Binder aktarımı
1 MB ile sınırlı. Koyu tema `values-night/kerteriz_renkler.xml`; bitmap
renkleri de `context.getColor` ile oradan geliyor. Gerçek animasyon yok:
RemoteViews desteklemiyor; efektler dokunma dalgası ve su düğmesinin kısa onayı.

**Gün içi (0.14.0):** 15 dakikalık dilimler (`DayRecord.gunNabzi`, `gunAdim`),
önbellekte yalnızca son 7 gün tutuluyor. Stres referansı dinlenme nabzı değil
sakin uyanık nabız: oturan birinin nabzı uykudakinden 10-15 atım yüksek, dinlenme
nabzına göre ölçmek herkesi gün boyu stresli gösterirdi. Enerji katsayıları
(`GunIci.yukKaybi`, `stresKaybi`, `uyaniklikKaybi`) veriden çıkmıyor, sabit;
"uydurma katsayı yok" ilkesinin bilinçli istisnası, bu yüzden ekranda tahmin
olduğu ve katsayıların ne olduğu yazıyor. Antrenmanlar isteğe bağlı izinle
okunuyor (`optionalTypes`); yeni isteğe bağlı izinler mevcut kullanıcılara
`yeniIzinleriSor` ile bir kez soruluyor.

**Testler:** `flutter test` (75 test). Formüllere dokunan her değişiklikten
sonra çalıştırılmalı.

**Sıradaki adımlar:**
1. HRV akıyor mu, Veri sekmesinden doğrula. Gelmiyorsa hazırlık kartı ve Veri
   sekmesi bunu artık açıkça söylüyor. Dakikalık nabızdan RMSSD türetilemez
   (atımdan atıma aralık gerekir), yani HRV'nin yerine geçecek dürüst bir
   türetme yok
2. ~2 hafta veri biriktir
3. Uygulamadan JSON dışa aktar, eşikleri kullanıcının kendi dağılımına göre kalibre et
   (uyku ihtiyacı tabanı, bölge ağırlıkları, seviye sınırları)
4. Play Store'a çıkış — `YAYIN.md`

---

## 8. Tasarım dili

**Eylül 2026'da değişti.** Kullanıcı Honor Magic 7'ye geçtikten sonra
uygulamanın işletim sistemiyle aynı dili konuşmasını istedi. Önceki dil
(Apple Style Guide: saf beyaz zemin, kartsız yapı) bırakıldı.

Yeni dil MagicOS'un yüzey diline yaklaşıyor:

- Sayfa zemini gri (`#F1F2F5`), içerik beyaz kartlarda
- Büyük köşe yarıçapı (kart 22), rozet ve düğmeler kapsül biçimli
- Çok yumuşak ve geniş gölge: amaç gölge göstermek değil, kartı zeminden
  ayırmak
- Aksan `#1668E3`
- Tipografi sistem yazı tipi; başlıklar daha kalın, sayılar tablo hizalı

**Seviye renkleri korundu.** Yeşil, turuncu ve kırmızı bu uygulamada süs
değil, veriyi okuma anahtarı. Her iki palette de (açık ve koyu) ayrı ayrı
dengelendi: koyu zeminde okunabilmeleri için açıldılar. Renk hiçbir yerde tek başına bırakılmadı: yanında her
zaman seviye etiketi ve sayının kendisi var.

**Hareket ve derinlik.** Uygulama donuk hissettiriyordu. Eklenenler:
ekranlar kademeli süzülerek giriyor, yay göstergesindeki sayı yayla birlikte
sıfırdan sayıyor, sütun grafikleri tabandan büyüyerek geliyor, çizgi
grafikleri soldan sağa çiziliyor, sekme değişimi yumuşak bir geçişle oluyor,
dokunulan satır hafifçe küçülüyor, kaydırınca üstte kompakt bir başlık
çubuğu beliriyor.

**Kullanıcının genel tercihi ayrı.** Sunum, belge ve görsel çıktılarda Apple
Style Guide dili varsayılan olmaya devam ediyor; bu değişiklik yalnızca
Kerteriz uygulamasının kendisi için.

## 9. Uygulamanın sınırları

- **Teşhis ya da tıbbi tavsiye vermez.** Kullanıcının kendi verisini kendi taban
  çizgisine göre gösterir, o kadar. Bu kural bozulmamalı.
- Skorlar mutlak değil, **kişiye göre**. HRV değeri kişiler arası karşılaştırılamaz.
- Yalnızca Android. iOS için Google Health API (B yolu) gerekir.

---

## 10. Para kazanma

**Karar: önce ücretsiz yayın, model sonra.** Uygulamada ödeme ekranı yok ve
"şimdilik ücretsiz" gibi bir vaat de verilmiyor — çünkü öyle bir cümle sonradan
ödeme duvarı konduğunda aleyhe kullanılır.

**Play kısıtı:** Health Connect verisi reklamda kullanılamaz, kişiselleştirilemez,
üçüncü taraflara aktarılamaz, satılamaz. Yani reklam modeli masada yok. Beyan formu
ve gizlilik politikası URL'i zorunlu.

Sonradan eklenirse kural: mevcut özellikler ödeme duvarının arkasına alınmayacak,
yalnızca yeni özellikler premium olacak.

---

## 11. Devralan asistana talimat

1. **Önce veri kapsamı ekranını sor** — HRV akıyor mu. Çoğu karar buna bağlı.
2. **Formülleri koru.** Üstteki metrikler düşünülerek seçildi; değiştirilecekse
   sebebi açıkça tartışılmalı. Özellikle HRV'nin log uzayındaki taban çizgisi.
3. **Bağımlılık sürümlerini değiştirme.** Bölüm 6'daki tablo çatışmalar çözülerek oluştu.
4. **Tasarım dilini uygula.** Beyaz zemin, kartsız yapı, seviye renkleri yanında etiket.
5. **Türkçe yaz, şapkalı karakter kullanma** — ama ç, ğ, ı, İ, ö, ş, ü tam kullanılır.
6. Kullanıcı yazılımcı değil: komutları tam ver, ne yaptığını ve **neden** yaptığını açıkla.
