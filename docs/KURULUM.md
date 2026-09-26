# Kerteriz — kurulum ve teknik notlar

Fitbit Air verisini **Google Health uygulaması → Health Connect → bu uygulama**
zinciriyle telefonda okur, bileşik metriklere çevirir ve gösterir.
Veri cihazdan çıkmaz; hiçbir sunucuya bağlantı yoktur.

---

## 1. Kurulum

Flutter SDK kurulu olmalı (`flutter doctor` temiz olsun). Sonra:

```bash
bash kurulum.sh
```

Betik ne yapıyor: `flutter create` ile platform klasörlerini üretiyor, `lib/` ve
`pubspec.yaml`'ı kopyalıyor, **Android dosyalarını yamalıyor** (üzerine yazmıyor),
uygulama ikonunu yerleştiriyor, `minSdk`'yı 28'e çekiyor ve `flutter pub get`
çalıştırıyor.

**Neden yamalama:** Elle yazılmış bir `AndroidManifest.xml`'i üzerine kopyalamak,
o dosyayı yazıldığı Flutter sürümüne bağlar. Sürüm değişince
`Build failed due to use of deleted Android v1 embedding` gibi hatalar çıkar.
Flutter'ın kendi ürettiği manifest, o sürümün beklediği embedding yapılandırmasını
zaten doğru taşır; `patch_manifest.py` yalnızca Health Connect izinlerini,
`queries` bloğunu ve izin gerekçesi ekranlarını ekler. `patch_mainactivity.py` de
`FlutterActivity`'yi `FlutterFragmentActivity`'ye çevirir, `patch_native.py` ise
su widget'ının Kotlin ve kaynak dosyalarını kopyalayıp gradle bağımlılıklarını
ekler. Üç betik de **idempotent**: aynı projede tekrar çalıştırmak zararsızdır.

Elle yapmak istersen:

```bash
flutter create --org com.kerteriz --project-name kerteriz ../kerteriz
cp -R lib ../kerteriz/lib
cp pubspec.yaml analysis_options.yaml ../kerteriz/
python3 patch_manifest.py ../kerteriz/android/app/src/main/AndroidManifest.xml
python3 patch_mainactivity.py ../kerteriz
python3 patch_native.py ../kerteriz
# android/app/build.gradle.kts içinde  minSdk = 28
cd ../kerteriz && flutter pub get
```

`android-manifest-referans.xml` yalnızca referans içindir; kullanılmaz.

Telefonu USB ile bağla, geliştirici modu ve USB hata ayıklama açık olsun:

```bash
flutter run
```

## 2. Telefonda yapılacaklar

1. **Google Health** uygulamasında Fitbit Air'in bağlı olduğundan emin ol.
2. Google Health → **Ayarlar → Health Connect** → Kerteriz'e okuma izni ver.
   Uygulama ilk açılışta bu ekranı kendisi çağırır. Listede su alımı için bir
   **yazma** izni de görünür; su widget'ı bunsuz çalışmaz, geri kalan her şey
   çalışır.
3. Google Health'in Health Connect'e **hangi tipleri yazdığını** aynı ekrandan
   kontrol et. Resmi listede adım, nabız, uyku evreleri, solunum hızı, cilt
   sıcaklığı ve VO2max var; **HRV ve SpO2 açıkça listelenmiyor.** Görünmüyorlarsa
   uygulama yine çalışır; aşağıya bak.
4. İzin listesinde **mesafe** ve **kalori** de var. Bunlar yalnızca özet
   widget'ının halkaları için; uygulamanın kendi ekranları ve skorları onları
   kullanmıyor, 90 günlük okumaya da girmiyorlar.

### Honor / MagicOS cihazlarda ek adımlar

MagicOS, arka planda çalışan uygulamaları Android'in standardından daha sert
kesiyor. Widget'lar yayın alıcısıyla çalıştığı için bu doğrudan onları vuruyor:
periyodik güncelleme atlanıyor, dokunuşlar bazen hiçbir şey yapmamış gibi
görünüyor. Kurulumdan sonra şunları aç:

1. **Optimizer** (Telefon Yöneticisi) > pil yüzdesine dokun > **Uygulama
   başlatma**: Kerteriz'i bul, **Otomatik yönet**'i kapat, açılan üç anahtarı
   da aç (otomatik başlat, ikincil başlatma, arka planda çalıştır).
2. **Ayarlar** içinde **Pil optimizasyonu** ara, listeyi **Tüm uygulamalar**
   yap, Kerteriz'i **İzin verme** olarak işaretle.
3. **Ayarlar** içinde **Cihaz uyurken bağlı kal** ayarını aç.
4. Pil tasarrufu modunu kapalı tut; açıkken widget güncellemeleri durur.

Bunları yapsan bile MagicOS bazen 30 dakikalık güncellemeyi atlıyor. İki widget
da bu yüzden elle yenilenebilir: su widget'ında düğmeye basmak, özet
widget'ında halkalara dokunmak anında yeniler.

## 3. Eksik veriyle davranış

Hazırlık skoru dört girdiyi ağırlıklandırır (HRV %40, dinlenme nabzı %25,
uyku skoru %25, solunum + sıcaklık %10). Bir girdi hiç yoksa **ağırlığı ötekilere
oransal olarak dağıtılır** (`MetricsEngine.run` içindeki `add()` bloğu), skor
yine 0–100 arasında kalır.

Dinlenme nabzı kaydı gelmiyorsa gece nabız serisinden türetilir: gecenin en düşük
30 dakikalık kararlı ortalaması. Cihazın yazdığı değerden biraz farklı çıkabilir
ama kendi içinde tutarlı olduğu için taban çizgi ve z-skoru doğru çalışır.

**Veri** sekmesi hangi tipin geldiğini ve hangi metriğin hesaplanabildiğini gösterir.

## 4. Kişisel ayarlar

`lib/config.dart`:

- `age` — maksimum nabız tahmini (Tanaka: 208 − 0.7 × yaş). Nabız bölgeleri buna bağlı.
- `historyDays` — kaç gün geriye okunacak (varsayılan 90).
- `baselineWindow` — taban çizgi penceresi (varsayılan 14 gün).
- `sleepNeedBaseMinutes` — uyku ihtiyacı taban değeri; üzerine dünkü yükün katkısı eklenir.
- `dailyWaterGoalMl` — günlük su hedefi (varsayılan 2500 ml). Hem Bugün sekmesi hem widget bunu kullanır.
- `waterServingMl` — widget'ın tek dokunuşta eklediği miktar (varsayılan 250 ml).
- `dailyStepGoal`, `dailyCalorieGoal`, `dailyActiveCalorieGoal`,
  `dailyDistanceTenthKm` — özet widget'ının halka hedefleri. Mesafe
  kilometrenin onda biri cinsinden tutulur (70 = 7,0 km).

## 5. Su widget'ı

Ana ekran widget'ı tek dokunuşla `waterServingMl` kadar su ekler ve toplamı
Health Connect'e `HydrationRecord` olarak yazar. Bugün sekmesi aynı kaydı
oradan geri okur — yani widget ile uygulama arasında ayrı bir veritabanı yok,
tek kaynak Health Connect.

Bu, uygulamanın **tek yazma iznidir**. Geri alma düğmesi yalnızca
`dataOrigin.packageName` bu uygulamaya ait olan son kaydı siler; başka bir
uygulamanın yazdığı su kaydına dokunmaz.

Widget'a ait dosyalar `native/` altında durur ve `patch_native.py` tarafından
Flutter'ın ürettiği Android projesine kopyalanır:

```
native/
  kotlin/SuWidgetProvider.kt   AppWidgetProvider, RemoteViews, ekle/geri al
  kotlin/SuKaydedici.kt        Health Connect istemcisi, okuma/yazma/silme
  res/layout/su_widget.xml     widget düzeni
  res/drawable/                zemin, düğme, ilerleme çubuğu
  res/values/                  renkler ve metinler
  res/xml/su_widget_info.xml   widget tanımı
```

Su alımı **hazırlık skoruna ağırlıkla girmez.** Etkisi gerçek ama bir katsayı
verecek kadar net değil; onun yerine Bugün sekmesinde
`MetricsEngine.hydrationEffect` ile kendi verinden hesaplanan karşılaştırma
gösterilir: hedefi tutturduğun günlerin ertesindeki hazırlık ortalaması ile
hedefin altında kaldığın günlerinki. Her iki grupta da en az dörder gün yoksa
hesap yapılmaz.

## 6. Özet widget'ı

Google Health'in kendi widget'ının karşılığı: solda üç halka (adım, kalori,
mesafe), sağda sayıların kendisi, altta hazırlık, uyku ve dinlenme nabzı.

Halkalar `Config` içindeki `dailyStepGoal`, `dailyCalorieGoal` ve
`dailyDistanceTenthKm` hedeflerine göre dolar. Cihaz toplam kalori yazmıyorsa
aktif kaloriye düşülür ve o zaman `dailyActiveCalorieGoal` kullanılır: aktif
kalori toplamın yaklaşık onda biri kadardır, aynı hedefe vurulamaz.

Halka renkleri aksan mavisinin üç tonudur. Yeşil, turuncu ve kırmızı bu
uygulamada **seviye** anlamı taşıdığı için halkalarda süs olarak kullanılmıyor.

**Adım, kalori ve mesafe** doğrudan Health Connect'ten okunur. **Hazırlık, uyku
ve dinlenme nabzı** 14 günlük taban çizgiye dayanan türetilmiş değerlerdir;
motor Dart tarafında çalıştığı için widget bunları hesaplayamaz. Uygulama her
açılışta `kerteriz_ozet.json` dosyasına yazar (uygulamanın kendi özel alanı,
dışarıdan erişilemez), widget oradan okur. Uygulama bir buçuk gündür açılmadıysa
ya da dosyadaki gün bugün veya dün değilse o üç kutu `--` gösterir ve altta
"Skorlar için uygulamayı aç" yazar.

Her toplam ayrı bir Health Connect sorgusudur. Tek istekte sorulsaydı, izin
verilmemiş tek bir tip bütün çağrıyı reddeder ve üç halka birden sıfır
görünürdü.

Halkalara dokunmak widget'ı yeniler, başka bir yere dokunmak uygulamayı açar.

## 7. Veriyi dışa aktarma

Sağ alttaki paylaş düğmesi, 90 günlük **ham + türetilmiş** veriyi tek bir JSON'a
yazıp paylaşım menüsünü açar. Dosyanın yapısı: `config`, `summary` (kapsama
oranları dahil) ve gün gün `days[]` — her günün ham alanları, uyku segmentleri,
gece nabız serisi ve `derived` altında tüm skorlar.

## 8. Dosya haritası

```
lib/
  config.dart                 kişisel sabitler
  l10n.dart                   iki dil (tr, en), 204 anahtar
  theme.dart                  renkler, tipografi, seviye eşikleri
  data/
    day_record.dart           gün modeli + JSON
    health_repository.dart    Health Connect okuma ve günlük toplama
    exporter.dart             JSON dışa aktarım
    ozet_yazici.dart          özet widget'ı için küçük JSON köprüsü
  metrics/
    engine.dart               taban çizgiler, z-skorları, bileşik metrikler
  ui/
    shell.dart                izin akışı, yükleme, sekmeler
    screens.dart              Bugün / Uyku / Yük / Kalp
    coverage_screen.dart      Veri — Health Connect tanı ekranı
    widgets/kit.dart          satır, ölçek, rozet
    widgets/gauge.dart        yay göstergesi, mini eğilim çizgisi
    widgets/charts.dart       CustomPainter grafikleri
native/
  kotlin/SuWidgetProvider.kt  su widget'ı
  kotlin/SuKaydedici.kt       Health Connect'e su yazma / okuma / silme
  kotlin/OzetWidgetProvider.kt  özet widget'ı
  kotlin/OzetOkuyucu.kt       günlük toplamlar + özet JSON okuma
  kotlin/HalkaCizer.kt        üç halkayı bitmap'e çizer
  res/                        widget düzenleri, çizimleri, renk ve metinleri
patch_manifest.py             izinler, queries ve widget alıcısı
patch_mainactivity.py         FlutterFragmentActivity'ye çevirir
patch_native.py               native/ içeriğini ve gradle bağımlılıklarını ekler
```

## 9. Metrik formülleri

| Metrik | Formül |
|---|---|
| z-skoru | `(x − ort14) / ss14`, HRV için `ln(x)` üzerinde |
| Hazırlık | `0.40·nz(z_HRV) + 0.25·nz(−z_RHR) + 0.25·(uyku/100) + 0.10·nz(−(z_sol+z_sıc)/2)` |
| Uyku skoru | `.35·süre + .20·verim + .25·onarım + .10·kesintisizlik + .10·zamanlama` |
| Uyku ihtiyacı | `438 dk + dünkü_yük × 2.2` |
| Uyku borcu | `Σ max(0, ihtiyaç−uyku) × 0.93^(gün farkı)`, son 14 gün |
| Günlük yük | `clamp(6.9 · ln(1 + ham/24), 0, 21)`, ham = Σ bölge_dk × [1.00, 1.85, 2.90, 4.60] + adım×0.0022 |
| ACWR | `ort(yük, 7 gün) / ort(yük, 28 gün)` |
| Kardiyak toparlanma | `0.55·clamp(düşüş/0.16) + 0.45·clamp((0.72−f_dip)/0.42)` |
| SRI | ardışık günlerde 10 dk'lık dilimlerde uyku/uyanık durumunun örtüşme yüzdesi |

## 10. Bağımlılık kısıtları

Bunlar acı çekilerek öğrenildi, değiştirilmemeli:

| Kısıt | Sebep |
|---|---|
| `intl: any` | `flutter_localizations` intl'i kesin sabitler; caret koymak sürüm çatışması üretir |
| `share_plus: ^13.3.0` | `health` → `device_info_plus 13` → `win32 ^6`; eski share_plus `win32 ^5` istiyor |
| Dart SDK ≥ 3.10 | `share_plus 13`'ün gereksinimi |
| `minSdk = 28` | Health Connect daha eskisinde çalışmıyor |
| `READ_HEALTH_DATA_HISTORY` | Olmadan 30 günden eski kayıt okunamaz; taban çizgiler buna bağlı |
| `FlutterFragmentActivity` | `health` paketi Android 14 için bunu şart koşuyor |
| Gri zemin, beyaz kart | Tasarım dili MagicOS'un yüzey diline yaklaştırıldı; `K` içindeki jetonlar tek kaynak |
| Widget düzeninde düz `View` yok | RemoteViews yalnızca `@RemoteView` işaretli sınıfları şişirebiliyor; `android.view.View` listede değil ve widget "eklenemedi" hatası veriyor. Ayraç için `FrameLayout` kullanılır |
| Tek WRITE izni `WRITE_HYDRATION` | Su widget'ı için şart; başka hiçbir tipe yazılmaz, bilinçli |

`share_plus 13`'te API değişti: `Share.shareXFiles(...)` yerine
`SharePlus.instance.share(ShareParams(files: [...]))`.

## 11. Dil

`lib/l10n.dart` içinde tek sınıf, iki harita (tr, en). Kod üretimi ya da ARB yok.
Cihaz dili desteklenmiyorsa İngilizceye düşer. Arayüzde düz metin bırakma,
`S.of(context).t('anahtar')` kullan; yer tutuculu metinler için
`t2('anahtar', {'x': değer})`. Yeni dil eklemek için bir harita daha yazıp
`_all`'a koymak yeterli.

## 12. Notlar

- Uygulama **hiçbir teşhis ya da tıbbi tavsiye vermez**; kendi verini kendi
  taban çizgine göre gösterir.
- Play Store'a çıkılacaksa gizlilik politikası URL'i ve `ViewPermissionUsageActivity`
  alias'ı zorunlu; alias'ı `patch_manifest.py` ekliyor.
- Özet widget'ı Health Connect'e hiçbir şey yazmaz, yalnızca okur.
- Widget'ın yazdığı su kayıtları Health Connect'te durur; uygulamayı silmek
  onları silmez. Health Connect → **Veri ve erişim → Beslenme → Su** yolundan
  temizlenebilir.
- Para kazanma şu an yok. Sonradan eklenirse mevcut özellikler ödeme duvarının
  arkasına alınmayacak; yalnızca yeni özellikler premium olacak.
