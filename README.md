<p align="center">
  <img src="docs/ikon.png" width="88" alt="Kerteriz">
</p>

<h1 align="center">Kerteriz</h1>

<p align="center">
  Fitbit ve Pixel verisini Health Connect uzerinden okuyup<br>
  hazirlik, uyku ve yuk skorlarina ceviren Android uygulamasi.<br>
  <sub>Veri cihazdan cikmaz.</sub>
</p>

<p align="center">
  <em>An Android app that turns Fitbit and Pixel data into readiness, sleep and load scores.<br>
  Everything is computed on device.</em>
</p>

---

## Ne yapiyor

Bileklik ham olcumler verir: nabiz, uyku evreleri, HRV. Bunlar tek baslarina az
sey soyler. Kerteriz onlari **kendi taban cizgine** gore normalize edip bilesik
metriklere cevirir — Whoop ve Bevel'in yaptigi ise yakin, ama veriyi hicbir yere
gondermeden.

| Metrik | Nasil |
|---|---|
| **Hazirlik** | HRV %40 · dinlenme nabzi %25 · uyku skoru %25 · solunum + cilt sicakligi %10 |
| **Uyku skoru** | Sure %35 · verim %20 · onarici evreler %25 · kesintisizlik %10 · zamanlama %10 |
| **Uyku borcu** | Son 14 gunun acigi, gunde %7 sonumlenerek |
| **Gunluk yuk** | Bolge agirlikli nabiz dakikalari (TRIMP), 0–21 logaritmik olcek |
| **ACWR** | 7 gunluk akut yuk / 28 gunluk kronik yuk |
| **Kardiyak toparlanma** | Gece nabzinin ne kadar *ve ne kadar erken* dustugu |
| **Sirkadiyen duzenlilik** | Sleep Regularity Index — ardisik gecelerin ortusmesi |

Taban cizgiler 14 gunluk penceredir ve HRV icin logaritmik uzayda kurulur
(RMSSD log-normal dagilir; ham ortalama yanlis sonuc verir).

## Tasarim ilkeleri

- **Renk tek basina anlam tasimaz.** Yesil-turuncu-kirmizi, kirmizi-yesil renk
  korlugunde ayirt edilemeyen ucludur; bu yuzden her renkli isaretin yaninda
  sayi ve seviye etiketi vardir.
- **Eksik veriyle calisir.** Bir girdi gelmiyorsa agirligi otekilere oransal
  dagitilir. Hangi metrigin calistigini **Veri** sekmesi acikca gosterir.
- **Teshis koymaz.** Kendi verini kendi taban cizgine gore gosterir, o kadar.

## Kurulum

Flutter SDK ve Android SDK gerekiyor. Ayrinti: [`docs/KURULUM.md`](docs/KURULUM.md)

```bash
bash kurulum.sh          # Flutter projesini uretir ve yamalar
cd ../kerteriz
flutter run              # telefon USB ile bagliyken
```

`kurulum.sh` Android dosyalarinin **uzerine yazmaz**, yamalar: Flutter'in urettigi
manifest o surumun embedding yapilandirmasini dogru tasir, betik yalnizca Health
Connect izinlerini ekler.

## Belgeler

| Dosya | Icerik |
|---|---|
| [`docs/PROJE.md`](docs/PROJE.md) | Mimari, kararlar ve gerekceler, butun formuller |
| [`docs/KURULUM.md`](docs/KURULUM.md) | Kurulum, dosya haritasi, bagimlilik kisitlari |
| [`docs/YAYIN.md`](docs/YAYIN.md) | Play Store yayin listesi, saglik verisi beyani |
| [`docs/GIZLILIK.md`](docs/GIZLILIK.md) | Gizlilik politikasi metni |

## Gizlilik

Uygulamanin sunucusu yoktur. Health Connect'e **yalnizca okuma** izniyle erisir,
hicbir sey yazmaz, analiz ve cokme raporlama kitapligi icermez, reklam gostermez.
Veri cihazdan yalnizca senin baslattigin disa aktarma ile cikar.

## Uyari

Kerteriz bir tibbi cihaz degildir. Teshis koymaz, tedavi onermez, tibbi tavsiye
vermez. Sagligiyla ilgili kararlar icin bir hekime danisilmalidir.

## Lisans

Tum haklari saklidir — bkz. [LICENSE](LICENSE).
