# Kerteriz — Play Store yayın kontrol listesi

Sırayla git. Sağlık verisi okuyan uygulamalarda inceleme normalden uzun sürer;
eksik bir madde reddin en sık sebebi.

---

## 1. İmzalama (tek seferlik)

Şu ana kadar release derlemeleri debug anahtarıyla imzalanıyordu. Play Store
gerçek bir imza ister ve **bu anahtarı kaybedersen uygulamayı bir daha
güncelleyemezsin** — yedeğini al.

```bash
keytool -genkey -v -keystore ~/kerteriz-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` oluştur (bu dosyayı asla paylaşma, git'e koyma):

```properties
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=upload
storeFile=/Users/<kullanıcı>/kerteriz-upload.jks
```

`android/app/build.gradle.kts` içinde `android { }` bloğundan ÖNCE:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

`android { }` içine:

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

Sonra Play'in istediği paket:

```bash
flutter build appbundle --release
# çıktı: build/app/outputs/bundle/release/app-release.aab
```

## 2. Gizlilik politikasını yayınla

`GIZLILIK.md` içeriğini bir web adresine koy. En kolay yol GitHub Pages ya da
Notion'da herkese açık bir sayfa. **URL'i not al**, Play Console iki yerde soracak.
İçindeki e-posta yer tutucusunu doldurmayı unutma.

## 3. Play Console — uygulama oluştur

- Uygulama adı: **Kerteriz**
- Varsayılan dil: Türkçe ya da İngilizce (ikisi de destekleniyor)
- Uygulama tipi: Uygulama · Ücretsiz

## 4. Sağlık uygulamaları beyanı  ← en kritik adım

**Policy → App content → Health apps** bölümünde Health Connect kullandığını
beyan edip **her izni tek tek gerekçelendirmen** gerekiyor. Genel ifadeler
reddediliyor; her satırda "hangi ekranda, hangi özellik için" yazmalısın.

Kullanabileceğin gerekçeler:

| İzin | Gerekçe |
|---|---|
| READ_SLEEP | Uyku skoru, uyku borcu ve sirkadiyen düzenlilik hesaplanır; Uyku sekmesinde evre dağılımı ve hipnogram olarak gösterilir. |
| READ_HEART_RATE | Gece nabız eğrisi ve kardiyak toparlanma; ayrıca nabız bölgelerinden günlük yük hesaplanır. |
| READ_RESTING_HEART_RATE | Hazırlık skorunun %25'ini oluşturur; Kalp sekmesinde taban çizgiye göre gösterilir. |
| READ_HEART_RATE_VARIABILITY | Hazırlık skorunun %40'ını oluşturur; Kalp sekmesinde 45 günlük seri ve taban çizgi şeridi olarak gösterilir. |
| READ_RESPIRATORY_RATE | Hastalık erken uyarı sinyalinin bileşeni; Kalp sekmesinde gösterilir. |
| READ_OXYGEN_SATURATION | Gece SpO2 takibi; Kalp sekmesinde ortalama ve en düşük değer olarak gösterilir. |
| READ_SKIN_TEMPERATURE | Hastalık erken uyarı sinyalinin ikinci bileşeni; kendi ortalamadan sapma olarak gösterilir. |
| READ_STEPS | Günlük yük hesabına katkıda bulunur; Yük sekmesinde gösterilir. |
| READ_EXERCISE | Egzersiz oturumları günlük yük hesabına girer. |
| READ_HEALTH_DATA_HISTORY | Bütün metrikler 14 günlük taban çizgiye dayanır; 30 günden eski kayıt okunamazsa skorlar hesaplanamaz. |

Ayrıca sorulacaklar ve doğru cevaplar:

- Veri üçüncü taraflarla paylaşılıyor mu? **Hayır**
- Veri reklam için kullanılıyor mu? **Hayır**
- Veri satılıyor mu? **Hayır**
- Veri sunucuya gönderiliyor mu? **Hayır, tüm işleme cihazda**

## 5. Data safety formu

Health apps beyanıyla tutarlı doldur:
- Toplanan veri: **yok** (cihaz dışına çıkmıyor)
- Paylaşılan veri: **yok**
- Şifreleme: aktarım olmadığı için uygulanmaz
- Silme talebi: uygulamayı kaldırmak yeterli

## 6. Mağaza listeleme metinleri

**Kısa açıklama (80 karakter):**
> Fitbit ve Pixel verini hazırlık, uyku ve yük skorlarına çeviren sade bir analiz.

**Short description (EN):**
> Turns your Fitbit and Pixel data into readiness, sleep and load scores.

**Uzun açıklama — tasarlarken uyulacaklar:**
- "Teşhis", "tedavi", "hastalık tespiti" gibi tıbbi iddia içermemeli
- Hangi cihazlarla çalıştığını açıkça yaz (Health Connect'e veri yazan her cihaz)
- Verinin cihazdan çıkmadığını öne çıkar — bu senin en güçlü farkın

## 7. Görseller

- Uygulama ikonu: `android-icons/play-store-512.png`
- Özellik grafiği: 1024 × 500
- Telefon ekran görüntüsü: en az 2, en fazla 8 (Bugün, Uyku, Kalp, Veri ekranları)
- Ekran görüntüsü alırken **release derlemesi** kullan, debug bandı görünmesin

## 8. Önce kapalı test

Doğrudan yayına çıkma. **Closed testing** ile birkaç kişiye aç, en az bir hafta
kullanılsın. Sebebi: taban çizgiler 14 gün ister, uygulamanın gerçek davranışını
ancak veri birikince görürsün. Ayrıca Play, yeni geliştirici hesapları için
yayın öncesi test süresi şart koşuyor — güncel kuralı Console'da kontrol et.

## 9. Yayın sonrası

- Health Connect politikası değişirse beyanı güncelle
- Farklı cihazlar farklı tipler yazıyor: Samsung Health, Garmin, Oura kullanıcıları
  farklı kapsam görecek. **Veri** sekmesi bu yüzden herkese açık kalmalı.
- Para kazanma sonradan eklenecekse: mevcut kullanıcıların elindeki özellikleri
  ödeme duvarının arkasına alma. Yeni özellikleri premium yap, eskiyi bırak.
