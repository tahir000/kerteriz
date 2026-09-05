# Kerteriz — Proje Brifingi

> Bu belge, projeyi baska bir yapay zeka asistanina devretmek icin hazirlandi.
> Amaci: kod okumadan once neyin neden boyle yapildigini anlatmak.
> Yanindaki `kerteriz-kaynak-kod.md` dosyasi butun Dart kaynagini icerir.

---

## 1. Tek cumleyle

Google **Fitbit Air** bileklikten gelen veriyi **Health Connect** uzerinden telefonda okuyup,
ham olculeri bilesik saglik metriklerine (hazirlik, uyku skoru, yuk, sirkadiyen duzenlilik)
ceviren, **Flutter** ile yazilmis kisisel bir Android uygulamasi. Veri cihazdan cikmiyor.

**Kullanici:** Tahir. Istanbul'da bir hukuk burosunda calisiyor, yazilimci degil ama teknik
konulari takip ediyor. Uygulamayi kendisi icin yapiyor.

---

## 2. Neden bu mimari — kritik zamanlama bilgisi

**Eski Fitbit Web API Eylul 2026'da tamamen kapandi.** Internette bulunan hemen her
"Fitbit API" ornegi, kutuphanesi ve tutorial'i artik olu. Yerine **Google Health API** geldi.

Iki erisim yolu var:

| | A — Health Connect (secilen) | B — Google Health API |
|---|---|---|
| Nerede calisir | Telefonda, cihaz uzerinde | Bulut, REST |
| Onay | Yok | Restricted scope, CASA denetimi |
| Maliyet | Yok | Yayina cikarken 500–4.500 USD |
| Kullanici siniri | Yok | Dogrulanmamis uygulama 100 kullanici |
| Platform | Yalnizca Android | Her yer |
| Cozunurluk | Google Health ne yazarsa | ~5 saniyelik nabiz dahil |

**A secildi.** Kisisel kullanim icin onay beklemeye ve ucret odemeye gerek yok, veri
telefondan cikmiyor, offline calisiyor. Ilerde yayina cikilirsa B'ye tasinabilir.

**Zincir:** Fitbit Air → Google Health uygulamasi → Health Connect → Kerteriz.

---

## 3. Cozulmemis en onemli soru

Google Health'in Health Connect'e yazdigi resmi tip listesinde **adim, nabiz, uyku evreleri,
solunum hizi, cilt sicakligi, VO2max, kilo** var. **HRV ve SpO2 bu listede acikca yer almiyor.**

Bu onemli, cunku **HRV hazirlik skorunun %40'i**. Uygulamaya bunun icin iki sey konuldu:

1. **Zarif bozulma:** bir girdi hic gelmezse agirligi otekilere oransal dagitilir,
   skor yine 0–100 arasinda kalir (`MetricsEngine.run` icindeki `add()` blogu).
2. **Veri kapsami ekrani** (5. sekme): Health Connect'ten tip tip kac kayit geldigini
   gosterir. Bir tip sifir gorunuyorsa sebebi orada tespit edilir.

**Devralan asistana:** Kullaniciya once bu ekrandaki HRV ve SpO2 satirlarini sor.
Sifirsalar ya agirliklar yeniden dagitilmali ya da B yoluna gecilmeli.

---

## 4. Turetilmis metrik sistemi

Projenin asil degeri burada. Ham veriyi Whoop/Bevel tarzinda bilesik metriklere ceviriyor.

### Katman 1 — normalize edilmis sapmalar

Her olcum kendi **14 gunluk taban cizgisine** gore z-skoruna cevrilir:

```
z      = (x - ort14) / ss14
nz(z)  = clamp(0.5 + z / 3.6, 0, 1)     # 0..1 araligina tasima
```

**HRV icin taban cizgi `ln(x)` uzerinde kurulur** — RMSSD log-normal dagilir, ham ortalama
yaniltir. Bu ayrinti atlanmamali.

### Katman 2 — bilesik skorlar

**Hazirlik (0–100)**
```
hazirlik = 100 * ( 0.40*nz(z_HRV)
                 + 0.25*nz(-z_RHR)              # dusuk nabiz iyi, isaret ters
                 + 0.25*(uyku_skoru/100)
                 + 0.10*nz(-(z_solunum + z_sicaklik)/2) )
```
Eksik girdi olursa agirliklar kalanlara oransal dagitilir.

**Uyku skoru (0–100)** — bes bilesenin agirlikli toplami
```
sure          = clamp(uyku / ihtiyac, 0, 1) * 100                    # %35
verim         = clamp((uyku/yatakta - 0.78) / 0.17, 0, 1) * 100      # %20
onarim        = clamp(((derin+rem)/uyku) / 0.42, 0, 1) * 100         # %25
kesintisizlik = clamp(100 - 4.5*uyanma - 0.55*uyanik_dk, 0, 100)     # %10
zamanlama     = clamp(100 - 1.05*|orta_nokta - 21g_ortalama|, 0, 100)# %10
```

**Uyku ihtiyaci** — sabit degil, dunku yuke gore kayar:
```
ihtiyac = 438 dk + dunku_yuk * 2.2
```

**Uyku borcu** — son 14 gun, gunde %7 sonumleme:
```
borc = SUM( max(0, ihtiyac_j - uyku_j) * 0.93^(bugun - j) )
```

**Gunluk yuk (0–21)** — Banister TRIMP mantigi, log olcek:
```
HRR      = (nabiz - dinlenme) / (maks - dinlenme)     # maks = 208 - 0.7*yas
bolgeler = [%50-60, %60-70, %70-85, %85+] HRR
agirlik  = [1.00, 1.85, 2.90, 4.60]
ham      = SUM(bolge_dk * agirlik) + adim * 0.0022
yuk      = clamp( 6.9 * ln(1 + ham/24), 0, 21 )
```

**ACWR — akut/kronik yuk orani**
```
oran = ort(yuk, son 7 gun) / ort(yuk, son 28 gun)
0.80–1.30 surdurulebilir · 0.60–1.50 sinir · disi riskli
```

**Gece kardiyak toparlanma (0–100)** — nabzin ne kadar *ve ne kadar erken* dip yaptigi
```
dusus = (ilk_hr - dip_hr) / ilk_hr
f_dip = dip_zamani / gece_suresi
skor  = 100 * ( 0.55*clamp(dusus/0.16,0,1) + 0.45*clamp((0.72-f_dip)/0.42,0,1) )
```

**SRI — Sleep Regularity Index (0–100)** — literaturdeki gercek metrik
```
Ardisik iki gunu 10 dakikalik 144 dilime bol.
Ayni dilimde ayni durumda (uyku/uyanik) olma yuzdesi, 30 gun uzerinden ortalama.
```

### Katman 3 — icgoruler

- **Hastalik erken uyarisi:** solunum z > 1.2 **ve** cilt sicakligi z > 1.0 **ve** nabiz z > 0.8,
  son 3 gunun en az 2'sinde. Uclusune birlikte bakmak tek basina nabza bakmaktan erken uyarir.
- **Yuklenme:** ACWR > 1.45 **ve** HRV uc gundur taban cizginin altinda.

---

## 5. Mimari ve dosya haritasi

```
lib/
  config.dart                 kisisel sabitler (yas, gecmis gun sayisi, taban pencere)
  data/
    day_record.dart           gun modeli + JSON serilestirme
    health_repository.dart    Health Connect okuma, gunluk toplama, kapsama takibi
    exporter.dart             90 gunluk ham+turetilmis veriyi JSON'a yazip paylasir
  metrics/
    engine.dart               taban cizgiler, z-skorlari, butun bilesik metrikler
  ui/
    shell.dart                izin akisi, yukleme, 5 sekme
    screens.dart              Bugun / Uyku / Yuk / Kalp
    coverage_screen.dart      Veri — Health Connect tani ekrani
    widgets/kit.dart          satir, bolgeli olcek, rozet, hero deger
    widgets/charts.dart       CustomPainter grafikleri (harici grafik kutuphanesi yok)
```

**Onemli tasarim karari:** gunler "uyanilan takvim gunu"ne yazilir. Sabah 18:00'dan once
biten uyku o gune, sonra bitenler ertesi gune. `HealthRepository._sleepDay()`.

**Gun iskeleti onceden olusturulur** ve arama fonksiyonu `null` doner — aksi halde aksam
saatindeki tek bir olcum "yarin" tarihli hayalet bir kayit uretiyordu.

---

## 6. Ortam ve bagimlilik kisitlari

Bunlar aci cekilerek ogrenildi, degistirilmemeli:

| Kisit | Sebep |
|---|---|
| `intl: ^0.20.2` | `health 13.3.2` bunu istiyor; `^0.19.0` catisiyor |
| `share_plus: ^13.3.0` | `health` → `device_info_plus 13` → `win32 ^6`; eski share_plus `win32 ^5` istiyor |
| Dart SDK ≥ 3.10 | `share_plus 13`'un gereksinimi |
| `minSdk = 28` | Health Connect daha eskisinde calismiyor |
| `READ_HEALTH_DATA_HISTORY` izni | Olmadan 30 gunden eski kayit okunamaz; taban cizgiler buna bagli |
| `FlutterFragmentActivity` | `health` paketi Android 14 icin bunu sart kosuyor |
| Manifestte yalnizca READ | Hicbir WRITE izni yok, bilincli |

`share_plus 13`'te API degisti: `Share.shareXFiles(...)` yerine
`SharePlus.instance.share(ShareParams(files: [...]))`.

**Android dosyalari uzerine yazilmaz, yamalanir.** Elle yazilmis bir
`AndroidManifest.xml`'i kopyalamak `Build failed due to use of deleted Android v1
embedding` hatasina yol acti. Flutter'in urettigi manifest o surumun embedding
yapilandirmasini dogru tasir; `patch_manifest.py` yalnizca Health Connect izinlerini,
`queries` blogunu ve gerekce ekranlarini ekler, `patch_mainactivity.py` de
`FlutterActivity` -> `FlutterFragmentActivity` cevirir. Ikisi de idempotent.

**Gelistirme ortami:** macOS (MacBook Air), **VS Code** (Flutter eklentisi ile),
Android Studio yalnizca Android SDK deposu olarak kurulu — editor olarak kullanilmiyor.
Test cihazi: Samsung SM-F956B (Galaxy Z Fold 6).

---

## 6b. Dil, tasarim ve yayin

- **Iki dil:** `lib/l10n.dart` — tek sinif, iki harita (tr/en), 197 anahtar.
  Kod uretimi yok. Arayuzde duz metin birakilmaz, `S.of(context).t('anahtar')`.
- **`intl: any` olmali** — `flutter_localizations` intl'i kesin sabitler.
- **Hero degerler yay gostergesi** (`ArcGauge`): 260 derecelik yay, seviye renginde
  dolan kavis, ortada sayi, altinda seviye etiketi. Renk asla tek basina anlam tasimaz.
- **Para kazanma karari:** once ucretsiz yayin, model sonra. Uygulamada odeme
  ekrani yok ve "simdilik ucretsiz" gibi bir vaat de verilmiyor. Sonradan
  eklenirse mevcut ozellikler odeme duvarinin arkasina alinmayacak.
- **Play kisiti:** Health Connect verisi reklamda kullanilamaz, satilamaz.
  Beyan formu ve gizlilik politikasi URL'i zorunlu. Ayrinti: `YAYIN.md`.

## 7. Durum

**Calisiyor:** Proje derleniyor, telefona kuruluyor, aciliyor. Health Connect izinleri
veriliyor, okuma yapiliyor.

**Bekleniyor:** Cihaz yeni alindi, henuz birkac gunluk veri var. Taban cizgiler icin
~14 gece gerekiyor. O zamana kadar z-skorlari sifira yakin cikar — hata degil.

**Bilinen kapsam (Fitbit Air + Google Health):** dinlenme nabzi, solunum hizi ve
SpO2 kaydi Health Connect'e yazilmiyor. Dinlenme nabzi gece nabiz serisinden
turetiliyor (en dusuk 30 dk kararli ortalama). Solunum ve SpO2 turetilemez;
kaybedilen tek ozellik hastalik erken uyarisi.

**Siradaki adimlar:**
1. HRV akiyor mu, Veri sekmesinden dogrula
2. ~2 hafta veri biriktir
3. Uygulamadan JSON disa aktar, esikleri kullanicinin kendi dagilimina gore kalibre et
   (uyku ihtiyaci tabani, bolge agirliklari, seviye sinirlari)
4. Istege bagli: Play Store'a cikis (gercek imza, gizlilik politikasi URL'i gerekir)

---

## 8. Tasarim dili — uyulmasi gereken kurallar

Kullanicinin butun ciktilarda uyguladigi Apple Style Guide temelli sistem:

- Saf beyaz zemin, renkli kart/blok yok, koyu sayfa yok
- Tipografi: SF Pro / sistem yazi tipi, serif kullanilmaz, hiyerarsi agirlikla kurulur
- Iki kademeli murekkep: `#1D1D1F` birincil, `#6E6E73` ikincil
- Tek dolgu rengi: `#F5F5F7` (yalnizca not bloklari)
- Kilcal ayrac cizgileri: `#D2D2D7` ve `#E8E8ED`
- Tek renkli aksan gerekirse baglanti mavisi `#0066CC`
- Madde imi kalin nokta degil orta nokta (·)

**Istisna — seviye renkleri:** kullanici acikca istedi. Yesil `#1B7A3E` / turuncu `#A85B00` /
kirmizi `#BE3125` (metin), isaretlerde `#34A853` / `#F09000` / `#E04A3F`.
Renk **hicbir zaman tek basina birakilmaz** — yaninda daima sayi ya da seviye etiketi var,
cunku yesil-turuncu-kirmizi renk korlugunde ayirt edilemeyen ucludur.

**Yazim kurali:** sapkali karakter kullanilmaz — â, î, û yerine duz a, i, u
("iflas", "hal" — "iflâs", "hâl" degil).

---

## 9. Uygulamanin sinirlari

- **Teshis ya da tibbi tavsiye vermez.** Kullanicinin kendi verisini kendi taban cizgisine
  gore gosterir, o kadar. Bu kural bozulmamali.
- Skorlar mutlak degil, **kisiye gore**. HRV degeri kisiler arasi karsilastirilamaz.
- Yalnizca Android. iOS icin Google Health API (B yolu) gerekir.

---

## 10. Devralan asistana talimat

Bu projede yardim ederken:

1. **Once veri kapsami ekranini sor** — HRV ve SpO2 akiyor mu. Cogu karar buna bagli.
2. **Formulleri koru.** Ustteki metrikler dusunulerek secildi; degistirilecekse sebebi
   acikca tartisilmali. Ozellikle HRV'nin log uzayindaki taban cizgisi.
3. **Bagimlilik surumlerini degistirme.** Bolum 6'daki tablo catismalar cozulerek olustu.
4. **Tasarim dilini uygula.** Beyaz zemin, kartsiz yapi, seviye renkleri yaninda etiket.
5. **Turkce yaz, sapkali karakter kullanma.**
6. Kullanici yazilimci degil: komutlari tam ver, ne yaptigini ve **neden** yaptigini acikla.
