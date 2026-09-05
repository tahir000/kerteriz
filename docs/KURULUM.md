# Kerteriz — Flutter + Health Connect iskeleti

Fitbit Air verisini **Google Health uygulamasi → Health Connect → bu uygulama**
zinciriyle telefonda okur, prototipteki bilesik metriklere cevirir ve gosterir.
Veri cihazdan cikmaz; hicbir sunucuya baglanti yoktur.

---

## 1. Kurulum

Flutter SDK kurulu olmali (`flutter doctor` temiz olsun). Sonra:

```bash
bash kurulum.sh
```

Betik ne yapiyor: `flutter create` ile platform klasorlerini uretiyor, `lib/` ve
`pubspec.yaml`'i kopyaliyor, **Android dosyalarini yamaliyor** (uzerine yazmiyor),
`minSdk`'yi 28'e cekiyor ve `flutter pub get` calistiriyor.

**Neden yamalama:** Elle yazilmis bir `AndroidManifest.xml`'i uzerine kopyalamak,
o dosyayi yazildigi Flutter surumune baglar. Surum degisince
`Build failed due to use of deleted Android v1 embedding` gibi hatalar cikar.
Flutter'in kendi urettigi manifest, o surumun bekledigi embedding yapilandirmasini
zaten dogru tasir; `patch_manifest.py` yalnizca Health Connect izinlerini,
`queries` blogunu ve izin gerekcesi ekranlarini ekler. `patch_mainactivity.py` de
`FlutterActivity`'yi `FlutterFragmentActivity`'ye cevirir. Iki betik de
**idempotent**: ayni projede tekrar calistirmak zararsizdir.

Elle yapmak istersen:

```bash
flutter create --org com.kerteriz --project-name kerteriz ../kerteriz
cp -R lib ../kerteriz/lib
cp pubspec.yaml analysis_options.yaml ../kerteriz/
python3 patch_manifest.py ../kerteriz/android/app/src/main/AndroidManifest.xml
python3 patch_mainactivity.py ../kerteriz
# android/app/build.gradle.kts icinde  minSdk = 28
cd ../kerteriz && flutter pub get
```

`android-manifest-referans.xml` yalnizca referans icindir; kullanilmaz.

Telefonu USB ile bagla, gelistirici modu ve USB hata ayiklama acik olsun:

```bash
flutter run
```

## 2. Telefonda yapilacaklar

1. **Google Health** uygulamasinda Fitbit Air'in bagli oldugundan emin ol.
2. Google Health → **Ayarlar → Health Connect** → Kerteriz'e okuma izni ver.
   Uygulama ilk acilista bu ekrani kendisi cagirir.
3. Google Health'in Health Connect'e **hangi tipleri yazdigini** ayni ekrandan
   kontrol et. Resmi listede adim, nabiz, uyku evreleri, solunum hizi, cilt
   sicakligi ve VO2max var; **HRV ve SpO2 acikca listelenmiyor.** Gorunmuyorlarsa
   uygulama yine calisir — asagiya bak.

## 3. Eksik veriyle davranis

Hazirlik skoru dort girdiyi agirliklandirir (HRV %40, dinlenme nabzi %25,
uyku skoru %25, solunum+sicaklik %10). Bir girdi hic yoksa **agirligi otekilere
oransal olarak dagitilir** (`MetricsEngine.run` icindeki `add()` blogu), skor
yine 0–100 arasinda kalir. Kalp ekranindaki metin de bunu soyler.

## 4. Kisisel ayarlar

`lib/config.dart`:

- `age` — maksimum nabiz tahmini (Tanaka: 208 − 0.7 × yas). Nabiz bolgeleri buna bagli.
- `historyDays` — kac gun geriye okunacak (varsayilan 90).
- `baselineWindow` — taban cizgi penceresi (varsayilan 14 gun).
- `sleepNeedBaseMinutes` — uyku ihtiyaci taban degeri; uzerine dunku yukun katkisi eklenir.

## 5. Veriyi disa aktarma

Sag alttaki paylas dugmesi, 90 gunluk **ham + turetilmis** veriyi tek bir JSON'a
yazip paylasim menusunu acar. Dosyanin yapisi: `config`, `summary` (kapsama
oranlari dahil) ve gun gun `days[]` — her gunun ham alanlari, uyku segmentleri,
gece nabiz serisi ve `derived` altinda tum skorlar.

## 6. Dosya haritasi

```
lib/
  config.dart                 kisisel sabitler
  data/
    day_record.dart           gun modeli + JSON
    health_repository.dart    Health Connect okuma ve gunluk toplama
    exporter.dart             JSON disa aktarim
  metrics/
    engine.dart               taban cizgiler, z-skorlari, bilesik metrikler
  ui/
    shell.dart                izin akisi, yukleme, sekmeler
    screens.dart              Bugun / Uyku / Yuk / Kalp
    widgets/kit.dart          satir, olcek, rozet, hero
    widgets/charts.dart       CustomPainter grafikleri
```

## 7. Metrik formulleri

| Metrik | Formul |
|---|---|
| z-skoru | `(x − ort14) / ss14`, HRV icin `ln(x)` uzerinde |
| Hazirlik | `0.40·nz(z_HRV) + 0.25·nz(−z_RHR) + 0.25·(uyku/100) + 0.10·nz(−(z_sol+z_sic)/2)` |
| Uyku skoru | `.35·sure + .20·verim + .25·onarim + .10·kesintisizlik + .10·zamanlama` |
| Uyku ihtiyaci | `438 dk + dunku_yuk × 2.2` |
| Uyku borcu | `Σ max(0, ihtiyac−uyku) × 0.93^(gun farki)`, son 14 gun |
| Gunluk yuk | `clamp(6.9 · ln(1 + ham/24), 0, 21)`, ham = Σ bolge_dk × [1.00, 1.85, 2.90, 4.60] + adim×0.0022 |
| ACWR | `ort(yuk, 7 gun) / ort(yuk, 28 gun)` |
| Kardiyak toparlanma | `0.55·clamp(dusus/0.16) + 0.45·clamp((0.72−f_dip)/0.42)` |
| SRI | ardisik gunlerde 10 dk'lik dilimlerde uyku/uyanik durumunun ortusme yuzdesi |

## 8. Notlar

- Uygulama **hicbir teshis ya da tibbi tavsiye vermez**; kendi verini kendi
  taban cizgine gore gosterir.
- 30 gunden eski kayitlar icin `READ_HEALTH_DATA_HISTORY` izni sarttir; manifestte var.
- Manifestte yalnizca **READ** izinleri var, hicbir WRITE yok.
- Play Store'a cikilacaksa gizlilik politikasi URL'i ve `ViewPermissionUsageActivity`
  alias'i zorunlu; alias manifestte hazir.

## 9. Gercek veriyi prototipe tasima

Disa aktardigin JSON'u sohbete birakirsan, prototipteki sentetik veri yerine
kendi 90 gunun konur; boylece esikleri (uyku ihtiyaci tabani, bolge agirliklari,
seviye sinirlari) kendi dagilimina gore kalibre edebiliriz. JSON'da ad, konum ya
da cihaz kimligi yoktur; yalnizca tarih ve olcum degerleri vardir.

## 10. APK uretme

### Android Studio ile
1. Once bir kez `bash kurulum.sh` calistir (platform klasorlerini uretir).
2. Android Studio → **Open** → uretilen `kerteriz` klasorunu ac.
3. **Build → Flutter → Build APK**.
4. Cikti: `build/app/outputs/flutter-apk/app-release.apk`

### Komut satiri ile
```bash
bash apk-olustur.sh
```
`flutter create`'in urettigi varsayilan yapilandirmada release derlemesi debug
anahtariyla imzalanir; ayrica bir keystore olusturmana gerek yok. Play Store'a
cikarken gercek imza gerekir.

Telefona kurmak: dosyayi telefona kopyalayip ac, "bilinmeyen kaynaklardan kurulum"
iznini ver. Ya da telefon USB ile bagliyken `flutter install --release`.

### Ilk derlemede tipik takiliklar

| Belirti | Cozum |
|---|---|
| `Android license status unknown` | `flutter doctor --android-licenses` |
| JDK surumu uyusmuyor | `flutter config --jdk-dir "<Android Studio'nun jbr yolu>"` |
| `minSdk` hatasi (Health Connect) | `android/app/build.gradle.kts` icinde `minSdk = 28` |
| `Unable to find MainActivity` | `MainActivity.kt` yolu `android/app/src/main/kotlin/com/kerteriz/kerteriz/` altinda olmali |
| Uygulama aciliyor ama izin ekrani gelmiyor | Android 9–13'te **Health Connect** uygulamasi Play Store'dan kurulmali; Android 14+ da sistemde gomulu |
| Grafikler bos | Google Health → Health Connect'te ilgili tiplerin yazilmasi acik mi, bak |

## 11. Surum notlari

- `health 13.3.2`, `intl ^0.20.2` istiyor. `pubspec.yaml` bu surumde sabitli.
  `version solving failed` hatasi goruyorsan once buraya bak.
- `health 13.3.2` -> `device_info_plus 13` -> `win32 ^6`. Bu yuzden `share_plus` da
  ayni win32 kusagindan olmali: `^13.3.0`. Eski `share_plus 10.x`, `win32 ^5.5.3`
  istedigi icin cakisiyor.
- `share_plus 13`'te paylasim API'si degisti: statik `Share.shareXFiles(...)` yerine
  `SharePlus.instance.share(ShareParams(files: [...]))`.
- Dart SDK alt siniri 3.10 (`share_plus 13`'un gereksinimi).
- `kurulum.sh`, `flutter create`'in biraktigi ornek `test/widget_test.dart` dosyasini siler;
  o dosya `MyApp` arar, bizim uygulama sinifimizin adi `KerterizApp`.

## 12. Veri kapsami ekrani

Alt sekmelerdeki **Veri**, Health Connect'ten tip tip kac kayit geldigini gosterir.
Veri henuz azken uygulama dogrudan bu ekranla aciliyor; skor ekranlarini bos bos
gostermek yaniltici olurdu.

Bir tip 0 gorunuyorsa sirasiyla bak: Google Health'te cihaz bagli mi, Health Connect'te
Google Health o tipi yazmaya yetkili mi, Kerteriz o tipi okumaya yetkili mi.
Ucu de aciksa veri gercekten yok demektir.

## 13. Dil ve yayin

- **Iki dil:** `lib/l10n.dart` icinde tek sinif, iki harita (tr, en). Kod uretimi
  ya da ARB yok. Cihaz dili desteklenmiyorsa Ingilizceye duser. Yeni dil eklemek
  icin bir harita daha yazip `_all`'a koymak yeterli.
- **Metin yazarken:** arayuzde duz metin birakma, `S.of(context).t('anahtar')`
  kullan. Yer tutuculu metinler icin `t2('anahtar', {'x': deger})`.
- **`intl: any`** — `flutter_localizations` intl surumunu kesin sabitler; caret
  koymak SDK yukseldiginde surum catismasi uretir.
- **Ikon:** `android-icons/` altinda butun yogunluklar hazir, `kurulum.sh`
  yerlestiriyor. Magaza ikonu `play-store-512.png`.
- **Yayin:** `YAYIN.md` — imzalama, saglik verisi beyani, magaza metinleri.
- **Gizlilik:** `GIZLILIK.md` — bir web adresine koyulmali, Play zorunlu tutuyor.
- **Para kazanma:** su an yok, planlanmiyor da degil. Sonradan eklenirse
  mevcut ozellikler odeme duvarinin arkasina alinmayacak; yalnizca yeni
  ozellikler premium olacak.
