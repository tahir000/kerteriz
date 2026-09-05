# Kerteriz — Play Store yayin kontrol listesi

Sirayla git. Saglik verisi okuyan uygulamalarda inceleme normalden uzun surer;
eksik bir madde reddin en sik sebebi.

---

## 1. Imzalama (tek seferlik)

Su ana kadar release derlemeleri debug anahtariyla imzalaniyordu. Play Store
gercek bir imza ister ve **bu anahtari kaybedersen uygulamayi bir daha
guncelleyemezsin** — yedegini al.

```bash
keytool -genkey -v -keystore ~/kerteriz-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` olustur (bu dosyayi asla paylasma, git'e koyma):

```properties
storePassword=<sifre>
keyPassword=<sifre>
keyAlias=upload
storeFile=/Users/<kullanici>/kerteriz-upload.jks
```

`android/app/build.gradle.kts` icinde `android { }` blogundan ONCE:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

`android { }` icine:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

Sonra Play'in istedigi paket:

```bash
flutter build appbundle --release
# cikti: build/app/outputs/bundle/release/app-release.aab
```

## 2. Gizlilik politikasini yayinla

`GIZLILIK.md` icerigini bir web adresine koy. En kolay yol GitHub Pages ya da
Notion'da herkese acik bir sayfa. **URL'i not al**, Play Console iki yerde soracak.
Icindeki e-posta yer tutucusunu doldurmayi unutma.

## 3. Play Console — uygulama olustur

- Uygulama adi: **Kerteriz**
- Varsayilan dil: Turkce ya da Ingilizce (ikisi de destekleniyor)
- Uygulama tipi: Uygulama · Ucretsiz

## 4. Saglik uygulamalari beyani  ← en kritik adim

**Policy → App content → Health apps** bolumunde Health Connect kullandigini
beyan edip **her izni tek tek gerekcelendirmen** gerekiyor. Genel ifadeler
reddediliyor; her satirda "hangi ekranda, hangi ozellik icin" yazmalisin.

Kullanabilecegin gerekceler:

| Izin | Gerekce |
|---|---|
| READ_SLEEP | Uyku skoru, uyku borcu ve sirkadiyen duzenlilik hesaplanir; Uyku sekmesinde evre dagilimi ve hipnogram olarak gosterilir. |
| READ_HEART_RATE | Gece nabiz egrisi ve kardiyak toparlanma; ayrica nabiz bolgelerinden gunluk yuk hesaplanir. |
| READ_RESTING_HEART_RATE | Hazirlik skorunun %25'ini olusturur; Kalp sekmesinde taban cizgiye gore gosterilir. |
| READ_HEART_RATE_VARIABILITY | Hazirlik skorunun %40'ini olusturur; Kalp sekmesinde 45 gunluk seri ve taban cizgi seridi olarak gosterilir. |
| READ_RESPIRATORY_RATE | Hastalik erken uyari sinyalinin bileseni; Kalp sekmesinde gosterilir. |
| READ_OXYGEN_SATURATION | Gece SpO2 takibi; Kalp sekmesinde ortalama ve en dusuk deger olarak gosterilir. |
| READ_SKIN_TEMPERATURE | Hastalik erken uyari sinyalinin ikinci bileseni; kendi ortalamadan sapma olarak gosterilir. |
| READ_STEPS | Gunluk yuk hesabina katkida bulunur; Yuk sekmesinde gosterilir. |
| READ_EXERCISE | Egzersiz oturumlari gunluk yuk hesabina girer. |
| READ_HEALTH_DATA_HISTORY | Butun metrikler 14 gunluk taban cizgiye dayanir; 30 gunden eski kayit okunamazsa skorlar hesaplanamaz. |

Ayrica sorulacaklar ve dogru cevaplar:

- Veri ucuncu taraflarla paylasiliyor mu? **Hayir**
- Veri reklam icin kullaniliyor mu? **Hayir**
- Veri satiliyor mu? **Hayir**
- Veri sunucuya gonderiliyor mu? **Hayir, tum isleme cihazda**

## 5. Data safety formu

Health apps beyaniyla tutarli doldur:
- Toplanan veri: **yok** (cihaz disina cikmiyor)
- Paylasilan veri: **yok**
- Sifreleme: aktarim olmadigi icin uygulanmaz
- Silme talebi: uygulamayi kaldirmak yeterli

## 6. Magaza listeleme metinleri

**Kisa aciklama (80 karakter):**
> Fitbit ve Pixel verini hazirlik, uyku ve yuk skorlarina ceviren sade bir analiz.

**Short description (EN):**
> Turns your Fitbit and Pixel data into readiness, sleep and load scores.

**Uzun aciklama — tasarlarken uyulacaklar:**
- "Teshis", "tedavi", "hastalik tespiti" gibi tibbi iddia icermemeli
- Hangi cihazlarla calistigini acikca yaz (Health Connect'e veri yazan her cihaz)
- Verinin cihazdan cikmadigini one cikar — bu senin en guclu farkin

## 7. Gorseller

- Uygulama ikonu: `android-icons/play-store-512.png`
- Ozellik grafigi: 1024 × 500
- Telefon ekran goruntusu: en az 2, en fazla 8 (Bugun, Uyku, Kalp, Veri ekranlari)
- Ekran goruntusu alirken **release derlemesi** kullan, debug bandi gorunmesin

## 8. Once kapali test

Dogrudan yayina cikma. **Closed testing** ile birkac kisiye ac, en az bir hafta
kullanilsin. Sebebi: taban cizgiler 14 gun ister, uygulamanin gercek davranisini
ancak veri birikince gorursun. Ayrica Play, yeni gelistirici hesaplari icin
yayin oncesi test suresi sart kosuyor — guncel kurali Console'da kontrol et.

## 9. Yayin sonrasi

- Health Connect politikasi degisirse beyani guncelle
- Farkli cihazlar farkli tipler yaziyor: Samsung Health, Garmin, Oura kullanicilari
  farkli kapsam gorecek. **Veri** sekmesi bu yuzden herkese acik kalmali.
- Para kazanma sonradan eklenecekse: mevcut kullanicilarin elindeki ozellikleri
  odeme duvarinin arkasina alma. Yeni ozellikleri premium yap, eskiyi birak.
