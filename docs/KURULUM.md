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
`FlutterActivity`'yi `FlutterFragmentActivity`'ye çevirir. İki betik de
**idempotent**: aynı projede tekrar çalıştırmak zararsızdır.

Elle yapmak istersen:

```bash
flutter create --org com.kerteriz --project-name kerteriz ../kerteriz
cp -R lib ../kerteriz/lib
cp pubspec.yaml analysis_options.yaml ../kerteriz/
python3 patch_manifest.py ../kerteriz/android/app/src/main/AndroidManifest.xml
python3 patch_mainactivity.py ../kerteriz
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
   Uygulama ilk açılışta bu ekranı kendisi çağırır.
3. Google Health'in Health Connect'e **hangi tipleri yazdığını** aynı ekrandan
   kontrol et. Resmi listede adım, nabız, uyku evreleri, solunum hızı, cilt
   sıcaklığı ve VO2max var; **HRV ve SpO2 açıkça listelenmiyor.** Görünmüyorlarsa
   uygulama yine çalışır — aşağıya bak.

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

## 5. Veriyi dışa aktarma

Sağ alttaki paylaş düğmesi, 90 günlük **ham + türetilmiş** veriyi tek bir JSON'a
yazıp paylaşım menüsünü açar. Dosyanın yapısı: `config`, `summary` (kapsama
oranları dahil) ve gün gün `days[]` — her günün ham alanları, uyku segmentleri,
gece nabız serisi ve `derived` altında tüm skorlar.

## 6. Dosya haritası

```
lib/
  config.dart                 kişisel sabitler
  l10n.dart                   iki dil (tr, en), 197 anahtar
  theme.dart                  renkler, tipografi, seviye eşikleri
  data/
    day_record.dart           gün modeli + JSON
    health_repository.dart    Health Connect okuma ve günlük toplama
    exporter.dart             JSON dışa aktarım
  metrics/
    engine.dart               taban çizgiler, z-skorları, bileşik metrikler
  ui/
    shell.dart                izin akışı, yükleme, sekmeler
    screens.dart              Bugün / Uyku / Yük / Kalp
    coverage_screen.dart      Veri — Health Connect tanı ekranı
    widgets/kit.dart          satır, ölçek, rozet
    widgets/gauge.dart        yay göstergesi, mini eğilim çizgisi
    widgets/charts.dart       CustomPainter grafikleri
```

## 7. Metrik formülleri

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

## 8. Bağımlılık kısıtları

Bunlar acı çekilerek öğrenildi, değiştirilmemeli:

| Kısıt | Sebep |
|---|---|
| `intl: any` | `flutter_localizations` intl'i kesin sabitler; caret koymak sürüm çatışması üretir |
| `share_plus: ^13.3.0` | `health` → `device_info_plus 13` → `win32 ^6`; eski share_plus `win32 ^5` istiyor |
| Dart SDK ≥ 3.10 | `share_plus 13`'ün gereksinimi |
| `minSdk = 28` | Health Connect daha eskisinde çalışmıyor |
| `READ_HEALTH_DATA_HISTORY` | Olmadan 30 günden eski kayıt okunamaz; taban çizgiler buna bağlı |
| `FlutterFragmentActivity` | `health` paketi Android 14 için bunu şart koşuyor |
| Manifestte yalnızca READ | Hiçbir WRITE izni yok, bilinçli |

`share_plus 13`'te API değişti: `Share.shareXFiles(...)` yerine
`SharePlus.instance.share(ShareParams(files: [...]))`.

## 9. Dil

`lib/l10n.dart` içinde tek sınıf, iki harita (tr, en). Kod üretimi ya da ARB yok.
Cihaz dili desteklenmiyorsa İngilizceye düşer. Arayüzde düz metin bırakma,
`S.of(context).t('anahtar')` kullan; yer tutuculu metinler için
`t2('anahtar', {'x': değer})`. Yeni dil eklemek için bir harita daha yazıp
`_all`'a koymak yeterli.

## 10. Notlar

- Uygulama **hiçbir teşhis ya da tıbbi tavsiye vermez**; kendi verini kendi
  taban çizgine göre gösterir.
- Play Store'a çıkılacaksa gizlilik politikası URL'i ve `ViewPermissionUsageActivity`
  alias'ı zorunlu; alias'ı `patch_manifest.py` ekliyor.
- Para kazanma şu an yok. Sonradan eklenirse mevcut özellikler ödeme duvarının
  arkasına alınmayacak; yalnızca yeni özellikler premium olacak.
