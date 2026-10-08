import 'package:flutter/material.dart';

/// Kullanıcının seçtiği tema. Sistem seçiliyse cihazın gece modu izlenir.
enum TemaTercihi { sistem, acik, koyu }

/// MagicOS'un yüzey diline yaklaştırılmış tema, açık ve koyu iki palet.
///
/// Renkler ve yazı biçimleri `static const` değil `static get`: gece modunda
/// aynı adlar farklı değer döndürüyor. Ölçü jetonları (boşluk, yarıçap)
/// temadan bağımsız olduğu için `const` kaldı.
///
/// Seviye renkleri (yeşil / turuncu / kırmızı) iki palette de var: onlar süs
/// değil, veriyi okuma anahtarı. Koyu zeminde okunacak şekilde açıldılar.
class K {
  /// Tüm palet bu bayrağa bakar. [KerterizApp] her yapımda ayarlıyor.
  static bool koyu = false;

  static Color _s(Color acik, Color koyuRenk) => koyu ? koyuRenk : acik;

  // yüzeyler
  static Color get bg => _s(const Color(0xFFF1F2F5), const Color(0xFF0E0F12));
  static Color get card => _s(const Color(0xFFFFFFFF), const Color(0xFF1A1C21));
  static Color get fill => _s(const Color(0xFFF4F5F8), const Color(0xFF23262C));
  static Color get fillSoft =>
      _s(const Color(0xFFFAFBFC), const Color(0xFF1E2127));

  // mürekkep
  static Color get ink => _s(const Color(0xFF17181C), const Color(0xFFF1F2F5));
  static Color get ink2 => _s(const Color(0xFF63666E), const Color(0xFFA4A9B3));
  static Color get ink3 => _s(const Color(0xFF93979F), const Color(0xFF7D838D));
  static Color get ink4 => _s(const Color(0xFFB6BAC1), const Color(0xFF5B606A));

  // çizgiler
  static Color get line => _s(const Color(0xFFDDE0E5), const Color(0xFF353942));
  static Color get line2 => _s(const Color(0xFFE9EBEF), const Color(0xFF2A2E36));
  static Color get line3 => _s(const Color(0xFFF2F3F6), const Color(0xFF23262C));

  static Color get accent =>
      _s(const Color(0xFF1668E3), const Color(0xFF4C9AFF));

  // seviye
  static Color get good => _s(const Color(0xFF1B7F49), const Color(0xFF5FD79A));
  static Color get goodMark =>
      _s(const Color(0xFF2FBF6B), const Color(0xFF35C46F));
  static Color get goodTint =>
      _s(const Color(0xFFE9F7EF), const Color(0xFF16301F));
  static Color get warn => _s(const Color(0xFFA35F00), const Color(0xFFFFC178));
  static Color get warnMark =>
      _s(const Color(0xFFFF9A1F), const Color(0xFFFF9A1F));
  static Color get warnTint =>
      _s(const Color(0xFFFEF3E4), const Color(0xFF33240E));
  static Color get bad => _s(const Color(0xFFBE3225), const Color(0xFFFF8C82));
  static Color get badMark =>
      _s(const Color(0xFFF1594C), const Color(0xFFF1594C));
  static Color get badTint =>
      _s(const Color(0xFFFCEBE9), const Color(0xFF35191A));

  // uyku evreleri
  static Color get stageDeep =>
      _s(const Color(0xFF14427A), const Color(0xFF3D7CC4));
  static Color get stageLight =>
      _s(const Color(0xFF4A8FD6), const Color(0xFF6FA8E4));
  static Color get stageRem =>
      _s(const Color(0xFF93B8E6), const Color(0xFFA7C8EF));
  static Color get stageWake =>
      _s(const Color(0xFFCBD1D9), const Color(0xFF4B5058));

  // ölçü jetonları: temadan bağımsız, const kalabilir
  static const double gutter = 18;
  static const double sectionGap = 26;
  static const double rKart = 22;
  static const double rIc = 14;
  static const double rDugme = 16;
  static const double kapsul = 999;

  /// Kart gölgesi. Koyu temada gölge neredeyse görünmez; kartı zeminden
  /// ayıran şey artık gölge değil, yüzeyin biraz daha açık olması.
  static List<BoxShadow> get golge => koyu
      ? const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4)),
        ]
      : const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1)),
        ];

  static List<BoxShadow> get cubukGolge => koyu
      ? const [
          BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 2)),
        ]
      : const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
        ];

  static BoxDecoration get kartDekor => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(rKart),
        boxShadow: golge,
      );

  static TextStyle get eyebrow => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      height: 1.3,
      color: ink3);
  static TextStyle get title => TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.12,
      color: ink);
  static TextStyle get titleSmall => TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.2,
      color: ink);
  static TextStyle get hero => TextStyle(
      fontSize: 60,
      fontWeight: FontWeight.w300,
      letterSpacing: -2.4,
      height: 1,
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle get heroUnit => TextStyle(
      fontSize: 17, fontWeight: FontWeight.w500, color: ink3, letterSpacing: -0.2);
  static TextStyle get rowTitle => TextStyle(
      fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: ink);
  static TextStyle get rowSub =>
      TextStyle(fontSize: 12.5, color: ink2, height: 1.4, letterSpacing: -0.05);
  static TextStyle get rowValue => TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle get caption =>
      TextStyle(fontSize: 14, color: ink2, height: 1.55, letterSpacing: -0.1);
  static TextStyle get axis =>
      TextStyle(fontSize: 10, color: ink3, letterSpacing: 0.1);
  static TextStyle get note =>
      TextStyle(fontSize: 13, color: ink2, height: 1.6, letterSpacing: -0.05);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: koyu ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          surface: bg,
          brightness: koyu ? Brightness.dark : Brightness.light,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );
}

enum Level { good, warn, bad }

extension LevelStyle on Level {
  Color get ink => switch (this) {
        Level.good => K.good,
        Level.warn => K.warn,
        Level.bad => K.bad,
      };
  Color get mark => switch (this) {
        Level.good => K.goodMark,
        Level.warn => K.warnMark,
        Level.bad => K.badMark,
      };
  Color get tint => switch (this) {
        Level.good => K.goodTint,
        Level.warn => K.warnTint,
        Level.bad => K.badTint,
      };
}

/// Eşikler ve etiket anahtarları. Metin değil ANAHTAR döner; çevirisi S'ten alınır.
class Levels {
  static Level score(num v) => v >= 80 ? Level.good : (v >= 60 ? Level.warn : Level.bad);
  static String scoreKey(num v) =>
      v >= 80 ? 'lvl.good' : (v >= 60 ? 'lvl.watch' : 'lvl.low');

  static Level readiness(num v) =>
      v >= 67 ? Level.good : (v >= 34 ? Level.warn : Level.bad);
  static String readinessKey(num v) =>
      v >= 67 ? 'lvl.ready' : (v >= 34 ? 'lvl.medium' : 'lvl.low');

  static Level z(num v) => v >= -0.5 ? Level.good : (v >= -1.5 ? Level.warn : Level.bad);
  static String zKey(num v) =>
      v >= -0.5 ? 'lvl.normal' : (v >= -1.5 ? 'lvl.below' : 'lvl.wellBelow');

  static Level acwr(num v) => (v >= 0.8 && v <= 1.3)
      ? Level.good
      : ((v >= 0.6 && v <= 1.5) ? Level.warn : Level.bad);
  static String acwrKey(num v) => (v >= 0.8 && v <= 1.3)
      ? 'lvl.inBand'
      : ((v >= 0.6 && v <= 1.5) ? 'lvl.borderline' : 'lvl.risky');

  static Level debt(num m) =>
      m < 180 ? Level.good : (m < 480 ? Level.warn : Level.bad);
  static String debtKey(num m) =>
      m < 180 ? 'lvl.low' : (m < 480 ? 'lvl.accumulating' : 'lvl.high');

  static Level sri(num v) => v >= 85 ? Level.good : (v >= 70 ? Level.warn : Level.bad);
  static String sriKey(num v) =>
      v >= 85 ? 'lvl.veryRegular' : (v >= 70 ? 'lvl.variable' : 'lvl.irregular');

  /// Su: günlük hedefe göre. Hedefin üstü yeterli, %70 üzeri izlenmeli.
  static Level water(num ml, num goal) =>
      ml >= goal ? Level.good : (ml >= goal * 0.7 ? Level.warn : Level.bad);
  static String waterKey(num ml, num goal) => ml >= goal
      ? 'lvl.enough'
      : (ml >= goal * 0.7 ? 'lvl.below' : 'lvl.wellBelow');

  /// Gün içi stres (0..1): düşük olan iyi.
  static Level stres(num v) =>
      v < 0.25 ? Level.good : (v < 0.5 ? Level.warn : Level.bad);
  static String stresKey(num v) =>
      v < 0.25 ? 'lvl.calm' : (v < 0.5 ? 'lvl.medium' : 'lvl.high');

  static Level dev(num absZ) =>
      absZ < 1 ? Level.good : (absZ < 2 ? Level.warn : Level.bad);
  static String devKey(num absZ) =>
      absZ < 1 ? 'lvl.steady' : (absZ < 2 ? 'lvl.drifting' : 'lvl.deviation');
}

String fmtDur(num minutes, {String h = 's', String m = 'd'}) {
  final t = minutes.round();
  return '${t ~/ 60}$h ${(t % 60).toString().padLeft(2, '0')}$m';
}

String fmtClock(DateTime? d) => d == null
    ? '--:--'
    : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String sgn(num v, {int digits = 2}) =>
    (v >= 0 ? '+' : '') + v.toStringAsFixed(digits);
