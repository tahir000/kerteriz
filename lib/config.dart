/// Uygulama sabitleri ve kullanıcı tercihlerinin **varsayılanları**.
///
/// 0.8.0'a kadar yaş ve hedefler doğrudan buradan okunuyordu. Artık
/// kullanıcı bunları ayarlar ekranından seçiyor ve seçim [Ayarlar] içinde
/// tutuluyor; buradaki değerler yalnızca ilk kurulumda ve widget'ların
/// derlemeye gömülü yedeğinde geçerli.
///
/// Motorun kendi sabitleri (taban çizgi penceresi, uyku ihtiyacı tabanı,
/// okunan gün sayısı) hala yalnızca burada: bunlar tercih değil, formülün
/// parçası.
class Config {
  /// Uygulama sürümü. pubspec.yaml ile aynı tutulmalı; Veri sekmesinde
  /// görünür ki telefonda hangi yapının çalıştığı tahmin edilmesin.
  static const String version = '0.11.0';

  /// Varsayılan yaş. Gerçek değer [Ayarlar.yas]; maksimum nabız tahmini
  /// oradan hesaplanıyor (Tanaka formülü: 208 - 0.7 * yaş).
  static const int age = 30;

  /// Health Connect'ten HİÇ okunmayacak tipler (HealthDataType adları).
  /// Bir tip eklentiyi çökertiyorsa adını buraya yazmak yeter; uygulama
  /// o tipi atlar ve geri kalanıyla çalışmaya devam eder.
  /// Örnek: `{'SKIN_TEMPERATURE'}`
  static const Set<String> atlananTipler = <String>{};

  /// Kaç günlük geçmiş okunsun. Taban çizgiler için en az 45 gün önerilir.
  /// 30 günden eskisi için READ_HEALTH_DATA_HISTORY izni şart.
  static const int historyDays = 90;

  /// Taban çizgi penceresi (gün).
  static const int baselineWindow = 14;

  /// Bir kalp girdisinin (HRV, dinlenme nabzı, solunum, sıcaklık) hazırlığa
  /// katılması için taban çizgisini kuran en az gece sayısı. Üç geceden
  /// hesaplanan bir standart sapma o kadar gürültülü ki z-skoru anlamsız;
  /// bu sayıya ulaşana kadar hazırlık kalan girdilerden kuruluyor.
  static const int minBaselineNights = 7;

  /// Uyku ihtiyacı taban değeri (dakika) — üzerine dünkü yükün katkısı eklenir.
  static const int sleepNeedBaseMinutes = 438;

  /// Varsayılan günlük su hedefi (ml). Gerçek değer [Ayarlar.suHedefiMl].
  /// Widget'ın derlemeye gömülü yedeği kurulumda buradan yazılır.
  static const int dailyWaterGoalMl = 2500;

  /// Widget'ın tek dokunuşta eklediği miktar (ml).
  static const int waterServingMl = 250;

  // --- özet widget'ının halka hedefleri (varsayılan) ---
  // Bu üçü yalnızca ana ekran widget'ında kullanılır; skorlara girmez.
  // Gerçek hedefler Ayarlar'da; widget onları kerteriz_ozet.json üzerinden
  // okuyor. patch_native.py buradaki sayıları kurulumda widget'a yazmaya
  // devam ediyor: uygulama hiç açılmadan widget eklenirse bunlar geçerli.

  /// Günlük adım hedefi.
  static const int dailyStepGoal = 10000;

  /// Günlük TOPLAM kalori hedefi (kcal), bazal dahil.
  static const int dailyCalorieGoal = 2400;

  /// Cihaz yalnızca AKTİF kalori yazıyorsa kullanılan hedef (kcal).
  /// Aktif kalori toplamın onda biri kadardır, aynı hedefe vurulamaz.
  static const int dailyActiveCalorieGoal = 600;

  /// Günlük mesafe hedefi, kilometrenin ONDA BİRİ cinsinden (70 = 7,0 km).
  /// Tam sayı tutuluyor ki Kotlin tarafına birebir aktarılabilsin.
  static const int dailyDistanceTenthKm = 70;

  /// Varsayılan hedef kalkış saati (gece yarısından dakika; 420 = 07:00).
  /// Gerçek değer [Ayarlar.kalkisDk].
  static const int wakeMinute = 420;

  /// Varsayılan yaşa göre maksimum nabız. Uygulamanın kullandığı değer
  /// [Ayarlar.hrMax]; bu yalnızca yedek.
  static double get hrMax => 208 - 0.7 * age;
}
