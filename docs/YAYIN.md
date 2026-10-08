# Kerteriz — Play Store yayın kontrol listesi

Sırayla git. Sağlık verisi okuyan uygulamalarda inceleme normalden uzun sürer;
eksik bir madde reddin en sık sebebi.

**Takvim beklentisi:** Play Console hesabın 13 Kasım 2023'ten sonra açılmış
kişisel bir hesapsa, üretime çıkmadan önce 12 test kullanıcısıyla kesintisiz
14 günlük kapalı test şartı var (bkz. adım 9). Bugün başlasan bile mağazada
görünmesi üç haftayı bulur. Hesabın daha eskiyse bu kural sana işlemiyor.

---

## 0. Hedef API sürümü  ← önce bunu doğrula

Google Play 31 Ağustos 2026'dan beri yeni yüklemelerde **Android 16
(API 36)** hedefini şart koşuyor. `flutter create`'in ürettiği yapılandırma
Flutter sürümüne bağlı, o yüzden elle kontrol et:

`~/kerteriz/android/app/build.gradle.kts` içinde

```kotlin
android {
    compileSdk = 36
    defaultConfig {
        targetSdk = 36
        minSdk = 28        // Health Connect icin 26+, guvenli taban 28
    }
}
```

Değiştirdikten sonra telefonda bir kez çalıştır ve Health Connect izin
akışının bozulmadığını gör. API 36'da izin ekranları değişebiliyor.

## 1. İmzalama (tek seferlik)

Şu ana kadar release derlemeleri debug anahtarıyla imzalanıyordu. Play Store
gerçek bir imza ister ve **bu anahtarı kaybedersen uygulamayı bir daha
güncelleyemezsin.** Yedeğini al, kimseyle paylaşma, depoya koyma.

```bash
keytool -genkey -v -keystore ~/kerteriz-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` oluştur (bu dosya `.gitignore` içinde):

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

`docs/index.html` hazır: iki dilli, tek dosya, dış bağımlılığı yok.
Yapman gereken iki şey var.

**a) E-posta adresini yaz.** Dosyada iki yerde `ORNEK@ORNEK.COM` geçiyor
(Türkçe ve İngilizce bölümlerin "İletişim" başlığında). İkisini de değiştir.
Play Console ayrıca mağaza sayfasında da bir iletişim adresi soracak; aynı
adresi kullan.

**b) GitHub Pages'i aç.** Depon zaten GitHub'da:

1. Depoda **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: **main**, klasör: **/docs** → Save
4. Bir iki dakika sonra adres hazır olur:
   `https://<kullanıcı-adın>.github.io/kerteriz/`

Bu adresi not al. Play Console iki yerde soracak ve **Health Connect içindeki
gizlilik bağlantısıyla aynı olmak zorunda.**

> `docs/.nojekyll` dosyası bilerek duruyor: Jekyll'in klasördeki .md
> dosyalarını işlemeye çalışmasını engelliyor.

## 3. Play Console — uygulama oluştur

- Uygulama adı: **Kerteriz**
- Varsayılan dil: Türkçe ya da İngilizce (ikisi de destekleniyor)
- Uygulama tipi: Uygulama · Ücretsiz
- Ülkeler: AB'ye açacaksan **tüccar (trader) beyanı** doldurman gerekiyor;
  doldurmak istemiyorsan ülke listesinden AB üyelerini çıkar

## 4. Sağlık uygulamaları beyanı  ← en kritik adım

**Policy → App content → Health apps** bölümünde Health Connect kullandığını
beyan edip **her izni tek tek gerekçelendirmen** gerekiyor. Genel ifadeler
reddediliyor; her satırda "hangi ekranda, hangi özellik için" yazmalısın.

Önce uygulama kategorisini seç: **Sağlık ve fitness → Etkinlik, Uyku.**
Tıbbi (Medical) kategorilerinin hiçbirini işaretleme: Kerteriz teşhis, tedavi,
ilaç ya da klinik destek iddiası taşımıyor, o kutuları işaretlemek incelemeyi
gereksiz yere tıbbi cihaz koluna sokar.

Sonra her veri tipi için gerekçe. Kopyala yapıştır:

| İzin | Gerekçe |
|---|---|
| READ_SLEEP | Uyku skoru, uyku borcu ve sirkadiyen düzenlilik hesaplanır; Uyku sekmesinde evre dağılımı, hipnogram ve uyku düzeni haritası olarak gösterilir. |
| READ_HEART_RATE | Gece nabız eğrisi ve kardiyak toparlanma; ayrıca nabız bölgelerinde geçen süreden günlük yük hesaplanır. Bölgeler kullanıcının ayarlardan girdiği yaşa göre belirlenir. |
| READ_RESTING_HEART_RATE | Hazırlık skorunun bileşenlerinden biri; Kalp sekmesinde 14 günlük taban çizgiye göre gösterilir. |
| READ_HEART_RATE_VARIABILITY | Hazırlık skorunun en ağırlıklı bileşeni; Kalp sekmesinde 45 günlük seri ve taban çizgi şeridi olarak gösterilir. |
| READ_RESPIRATORY_RATE | Hastalık erken uyarı sinyalinin bileşeni; Kalp sekmesinde taban çizgiden sapma olarak gösterilir. |
| READ_OXYGEN_SATURATION | Gece SpO2 takibi; Kalp sekmesinde ortalama ve en düşük değer olarak gösterilir. |
| READ_SKIN_TEMPERATURE | Hastalık erken uyarı sinyalinin ikinci bileşeni; kullanıcının kendi ortalamasından sapma olarak gösterilir. |
| READ_STEPS | Günlük yük hesabına katkıda bulunur; Yük sekmesinde ve ana ekran özet widget'ında kullanıcının kendi belirlediği hedefe göre halka olarak gösterilir. |
| READ_DISTANCE | Ana ekran özet widget'ında günün mesafesi, kullanıcının ayarladığı hedefe göre halka olarak gösterilir. |
| READ_EXERCISE | Yük sekmesinde antrenman listesi: her antrenmanın türü, süresi, o saatlerin nabzından hesaplanan yükü ve nabız bölgeleri, ertesi sabahki hazırlık. Gün içi stres hesabında antrenman saatleri stres sayılmaz. İsteğe bağlıdır: verilmezse uygulama çalışmaya devam eder. |
| READ_TOTAL_CALORIES_BURNED / READ_ACTIVE_CALORIES_BURNED | Ana ekran özet widget'ında günün kalorisi halka olarak gösterilir; cihaz toplam kalori yazmıyorsa aktif kaloriye ve onun kendi hedefine düşülür. |
| READ_HEALTH_DATA_HISTORY | Bütün metrikler 14 günlük taban çizgiye dayanır ve uygulama 90 günlük geçmiş okur; 30 günden eski kayıt okunamazsa skorlar hesaplanamaz. |
| READ_HYDRATION | Bugün eklenen su toplamı Bugün sekmesinde kullanıcının belirlediği hedefe göre gösterilir ve hedefin tutturulduğu günlerin ertesindeki hazırlık ortalamasıyla karşılaştırılır. |
| WRITE_HYDRATION | Ana ekran widget'ındaki düğmeye her basışta kullanıcının kendi eylemiyle bir su kaydı eklenir; miktarı kullanıcı ayarlardan belirler. Geri alma düğmesi yalnızca uygulamanın kendi yazdığı son kaydı siler. |

Ayrıca sorulacaklar ve doğru cevaplar:

- Veri üçüncü taraflarla paylaşılıyor mu? **Hayır**
- Veri reklam için kullanılıyor mu? **Hayır**
- Veri satılıyor mu? **Hayır**
- Veri sunucuya gönderiliyor mu? **Hayır, tüm işleme cihazda**
- Uygulama Health Connect'e veri yazıyor mu? **Evet, yalnızca su alımı
  (`WRITE_HYDRATION`)**; kullanıcının widget'ta düğmeye basmasıyla oluşur,
  cihazdan çıkmaz. Başka hiçbir tipe yazılmaz.

> Bu satırı atlama. Beyanda "hiçbir şey yazmıyoruz" deyip manifestte
> `WRITE_HYDRATION` bulunması, incelemede doğrudan ret sebebi.

## 5. Data safety formu

Health apps beyanıyla tutarlı doldur:

- Toplanan veri: **yok** (cihaz dışına çıkmıyor)
- Paylaşılan veri: **yok**
- Şifreleme: aktarım olmadığı için uygulanmaz
- Silme talebi: uygulamayı kaldırmak yeterli

Dışa aktarma özelliğini "veri toplama" diye işaretleme: dosya kullanıcının
kendi eylemiyle oluşuyor, sana ya da üçüncü bir tarafa gitmiyor.

## 6. Mağaza listeleme metinleri

`docs/MAGAZA.md` içinde hazır: uygulama adı, iki dilde kısa ve uzun açıklama,
sürüm notları, kategori ve etiket önerisi. Karakter sayıları da orada yazılı.

## 7. Görseller

Play Console'un istediği boyutlar:

| Neyi | Boyut | Kaç tane |
|---|---|---|
| Uygulama ikonu | 512 × 512 PNG | 1 (hazır: `android-icons/play-store-512.png`) |
| Özellik grafiği | 1024 × 500 PNG | 1 |
| Telefon ekran görüntüsü | kısa kenar en az 1080 px, oran 16:9 ile 9:16 arası | en az 2, en fazla 8 |

**Ekran görüntüsü nasıl alınır**

1. **Release derlemesiyle** al (`flutter install --release`), debug bandı
   görünmesin
2. Telefonda ses kısma + güç tuşu
3. Sırasıyla şu beş ekranı al, bu sıra hikayeyi anlatıyor:
   - **Bugün** — hazırlık halkası ve günün özeti (ilk görsel bu olsun)
   - **Uyku** — evre dağılımı ve hipnogram
   - **Yük** — günlük yük grafiği
   - **Kalp** — gece nabız eğrisi
   - **Veri** — kapsama ekranı, "hangi veri geliyor" dürüstlüğü
4. İstersen bir de **ana ekranı** widget'lar görünecek şekilde al
5. Koyu temada ikinci bir set almak iyi olur ama şart değil; tek set yeterli

Ekran görüntülerinde kişisel sayıların görünür olacağını unutma (nabız, uyku
süresi). Rahatsız ediyorsa önce boş bir Health Connect profiliyle al.

**Özellik grafiği (1024 × 500)**

Play bunu mağaza üstünde ve tanıtım yerlerinde kullanıyor. Sade tut:

- Beyaz ya da çok koyu düz zemin, gradyan yok
- Solda uygulama adı (Kerteriz) ve tek satır alt başlık
- Sağda telefon çerçevesiz bir ekran görüntüsü ya da yalnızca hazırlık halkası
- **Metni kenarlardan 100 px içeride tut:** Play bu grafiği farklı oranlarda
  kırpıyor, kenara yazılan yazı kesiliyor
- Ekran görüntüsü kolajı yapma, Play bunu sevmiyor
- Canva'da "Google Play Feature Graphic" şablonu doğru boyutta açılıyor

## 8. İçerik derecelendirmesi ve hedef kitle

- Anket: şiddet yok, cinsellik yok, kullanıcı içeriği yok, konum paylaşımı yok
- Hedef yaş: **18+**. Gizlilik politikasında da öyle yazıyor, tutarlı olsun
- Reklam içeriyor mu: **Hayır**

## 9. Önce kapalı test  ← zaman alan adım

Play Console hesabın 13 Kasım 2023'ten sonra açılmış **kişisel** bir hesapsa,
üretime geçmeden önce:

- **en az 12 test kullanıcısı**
- **kesintisiz 14 gün** kayıtlı kalmaları (araya girip çıkmak sayacı sıfırlar)

14 gün dolunca Console'daki **Apply for production** başvurusunu yaparsın;
inceleme genelde bir haftayı bulmaz. Başvuruda testin nasıl geçtiği, gelen
geri bildirim ve neyi düzelttiğin soruluyor, o yüzden test boyunca kısa not
tut.

Kuruluş (organization) hesaplarında bu şart yok. Hesabının tipini
**Play Console → Setup → Account details** altında görürsün.

Bu zorunluluk olmasa bile kapalı test mantıklı: taban çizgiler 14 gün ister,
uygulamanın gerçek davranışını ancak veri birikince görürsün.

## 10. Yayın sonrası

- Health Connect politikası değişirse beyanı güncelle
- Farklı cihazlar farklı tipler yazıyor: Samsung Health, Garmin, Oura
  kullanıcıları farklı kapsam görecek. **Veri** sekmesi bu yüzden herkese
  açık kalmalı
- Hedef API sürümü her yıl yükseliyor; Play uyarıyı Console'da gösteriyor,
  ertelemeden yükselt
- Para kazanma sonradan eklenecekse: mevcut kullanıcıların elindeki
  özellikleri ödeme duvarının arkasına alma. Yeni özellikleri premium yap,
  eskiyi bırak
