/// Kisisel sabitler. Kendi degerlerinle degistir.
class Config {
  /// Yasin — maksimum nabiz tahmini icin (Tanaka formulu: 208 - 0.7 * yas).
  static const int age = 30;

  /// Kac gunluk gecmis okunsun. Taban cizgiler icin en az 45 gun onerilir.
  /// 30 gunden eskisi icin READ_HEALTH_DATA_HISTORY izni sart.
  static const int historyDays = 90;

  /// Taban cizgi penceresi (gun).
  static const int baselineWindow = 14;

  /// Uyku ihtiyaci taban degeri (dakika) — uzerine dunku yukun katkisi eklenir.
  static const int sleepNeedBaseMinutes = 438;

  static double get hrMax => 208 - 0.7 * age;
}
