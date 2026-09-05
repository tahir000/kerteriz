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

Fitbit Air + Google Health birleşiminde **dinlenme nabzı, solunum hızı ve SpO2**
kaydı Health Connect'e yazılmıyor. Nabız serisi, uyku evreleri ve adım yazılıyor.

- **Dinlenme nabzı türetiliyor:** gecenin en düşük 30 dakikalık kararlı ortalaması.
  Cihazın yazacağı değerden biraz farklı çıkabilir ama kendi içinde tutarlı olduğu
  için taban çizgi ve z-skoru doğru çalışır.
- **Solunum ve SpO2 türetilemez.** Kaybedilen tek özellik hastalık erken uyarısı.
- **HRV** durumu doğrulanmalı — hazırlık skorunun %40'ı.

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
Eksik girdi olursa ağırlıklar kalanlara oransal dağıtılır.

**Uyku skoru (0–100)** — beş bileşenin ağırlıklı toplamı
```
süre          = clamp(uyku / ihtiyaç, 0, 1) * 100                    # %35
verim         = clamp((uyku/yatakta - 0.78) / 0.17, 0, 1) * 100      # %20
onarım        = clamp(((derin+rem)/uyku) / 0.42, 0, 1) * 100         # %25
kesintisizlik = clamp(100 - 4.5*uyanma - 0.55*uyanık_dk, 0, 100)     # %10
zamanlama     = clamp(100 - 1.05*|orta_nokta - 21g_ortalama|, 0, 100)# %10
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
- **Yüklenme:** ACWR > 1.45 **ve** HRV üç gündür taban çizginin altında.

---

## 5. Mimari ve dosya haritası

```
lib/
  config.dart                 kişisel sabitler
  l10n.dart                   iki dil (tr, en), 197 anahtar
  theme.dart                  renkler, tipografi, seviye eşikleri
  data/
    day_record.dart           gün modeli + JSON serileştirme
    health_repository.dart    Health Connect okuma, günlük toplama, kapsama takibi
    exporter.dart             90 günlük ham+türetilmiş veriyi JSON'a yazıp paylaşır
  metrics/
    engine.dart               taban çizgiler, z-skorları, bütün bileşik metrikler
  ui/
    shell.dart                izin akışı, yükleme, 5 sekme
    screens.dart              Bugün / Uyku / Yük / Kalp
    coverage_screen.dart      Veri — Health Connect tanı ekranı
    widgets/kit.dart          satır, bölgeli ölçek, rozet
    widgets/gauge.dart        yay göstergesi, mini eğilim çizgisi, giriş animasyonu
    widgets/charts.dart       CustomPainter grafikleri (harici grafik kütüphanesi yok)
```

**Önemli tasarım kararı:** günler "uyanılan takvim günü"ne yazılır. Sabah 18:00'dan
önce biten uyku o güne, sonra bitenler ertesi güne. `HealthRepository._sleepDay()`.

**Gün iskeleti önceden oluşturulur** ve arama fonksiyonu `null` döner — aksi halde
akşam saatindeki tek bir ölçüm "yarın" tarihli hayalet bir kayıt üretiyordu.

**Android dosyaları üzerine yazılmaz, yamalanır.** Elle yazılmış bir
`AndroidManifest.xml`'i kopyalamak `Build failed due to use of deleted Android v1
embedding` hatasına yol açtı. `patch_manifest.py` ve `patch_mainactivity.py`
idempotent yamalayıcılardır.

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
| Manifestte yalnızca READ | Hiçbir WRITE izni yok, bilinçli |

`share_plus 13`'te API değişti: `Share.shareXFiles(...)` yerine
`SharePlus.instance.share(ShareParams(files: [...]))`.

**Geliştirme ortamı:** macOS (MacBook Air), **VS Code** (Flutter eklentisi ile),
Android Studio yalnızca Android SDK deposu olarak kurulu — editör olarak
kullanılmıyor. Test cihazı: Samsung SM-F956B (Galaxy Z Fold 6).

---

## 7. Durum

**Çalışıyor:** Proje derleniyor, telefona kuruluyor, açılıyor. Health Connect
izinleri veriliyor, okuma yapılıyor.

**Bekleniyor:** Cihaz yeni alındı, henüz birkaç günlük veri var. Taban çizgiler için
~14 gece gerekiyor. O zamana kadar z-skorları sıfıra yakın çıkar — hata değil.

**Sıradaki adımlar:**
1. HRV akıyor mu, Veri sekmesinden doğrula
2. ~2 hafta veri biriktir
3. Uygulamadan JSON dışa aktar, eşikleri kullanıcının kendi dağılımına göre kalibre et
   (uyku ihtiyacı tabanı, bölge ağırlıkları, seviye sınırları)
4. Play Store'a çıkış — `YAYIN.md`

---

## 8. Tasarım dili

- Saf beyaz zemin, renkli kart/blok yok, koyu sayfa yok
- Tipografi: sistem yazı tipi, serif kullanılmaz, hiyerarşi ağırlıkla kurulur
- İki kademeli mürekkep: `#1D1D1F` birincil, `#6E6E73` ikincil
- Tek dolgu rengi: `#F5F5F7` (yalnızca not blokları)
- Kılcal ayraç çizgileri: `#D2D2D7` ve `#E8E8ED`
- Tek renkli aksan gerekirse bağlantı mavisi `#0066CC`
- Madde imi kalın nokta değil orta nokta (·)

**Seviye renkleri:** yeşil `#1B7A3E` / turuncu `#A85B00` / kırmızı `#BE3125` (metin),
işaretlerde `#34A853` / `#F09000` / `#E04A3F`. Renk **hiçbir zaman tek başına
bırakılmaz** — yanında daima sayı ya da seviye etiketi var, çünkü yeşil-turuncu-kırmızı
renk körlüğünde ayırt edilemeyen üçlüdür.

**Hero değerler yay göstergesi** (`ArcGauge`): 260 derecelik yay, seviye renginde
dolan kavis, ortada sayı, altında seviye etiketi.

**Yazım kuralı:** şapkalı karakter kullanılmaz — â, î, û yerine düz a, i, u
("iflas", "hal"). Bunun dışındaki bütün Türkçe karakterler tam kullanılır:
ç, ğ, ı, İ, ö, ş, ü.

---

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
