/// Kişisel sabitler. Kendi değerlerinle değiştir.
class Config {
  /// Uygulama sürümü. pubspec.yaml ile aynı tutulmalı; Veri sekmesinde
  /// görünür ki telefonda hangi yapının çalıştığı tahmin edilmesin.
  static const String version = '0.7.0';

  /// Yaşın — maksimum nabız tahmini için (Tanaka formülü: 208 - 0.7 * yaş).
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

  /// Uyku ihtiyacı taban değeri (dakika) — üzerine dünkü yükün katkısı eklenir.
  static const int sleepNeedBaseMinutes = 438;

  /// Günlük su hedefi (ml). Widget'ın varsayılanı da kurulumda buradan yazılır.
  static const int dailyWaterGoalMl = 2500;

  /// Widget'ın tek dokunuşta eklediği miktar (ml).
  static const int waterServingMl = 250;

  // --- özet widget'ının halka hedefleri ---
  // Bu üçü yalnızca ana ekran widget'ında kullanılır; skorlara girmez.
  // patch_native.py kurulum sırasında bu değerleri widget'a yazar.

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

  static double get hrMax => 208 - 0.7 * age;
}
