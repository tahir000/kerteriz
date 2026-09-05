import 'package:flutter/material.dart';

/// Apple Style Guide temelli beyaz zemin + seviye renkleri.
class K {
  // yuzeyler
  static const bg = Color(0xFFFFFFFF);
  static const fill = Color(0xFFF5F5F7);
  static const fillSoft = Color(0xFFFAFAFC);

  // murekkep
  static const ink = Color(0xFF1D1D1F);
  static const ink2 = Color(0xFF6E6E73);
  static const ink3 = Color(0xFF8E8E93);
  static const ink4 = Color(0xFFAEAEB2);

  // cizgiler
  static const line = Color(0xFFD2D2D7);
  static const line2 = Color(0xFFE8E8ED);
  static const line3 = Color(0xFFF0F0F3);

  static const accent = Color(0xFF0066CC);

  // seviye
  static const good = Color(0xFF1B7A3E);
  static const goodMark = Color(0xFF34A853);
  static const goodTint = Color(0xFFE8F5EC);
  static const warn = Color(0xFFA85B00);
  static const warnMark = Color(0xFFF09000);
  static const warnTint = Color(0xFFFDF0E3);
  static const bad = Color(0xFFBE3125);
  static const badMark = Color(0xFFE04A3F);
  static const badTint = Color(0xFFFBEAE8);

  // uyku evreleri
  static const stageDeep = Color(0xFF0B3F73);
  static const stageLight = Color(0xFF4A8FD6);
  static const stageRem = Color(0xFF93B8E6);
  static const stageWake = Color(0xFFC7CDD4);

  // olcek
  static const double gutter = 20;
  static const double sectionGap = 30;

  static const eyebrow = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.9,
      height: 1.3,
      color: ink3);
  static const title = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      height: 1.15,
      color: ink);
  static const hero = TextStyle(
      fontSize: 60,
      fontWeight: FontWeight.w300,
      letterSpacing: -2.4,
      height: 1,
      color: ink);
  static const heroUnit = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w400, color: ink3, letterSpacing: -0.2);
  static const rowTitle = TextStyle(
      fontSize: 15.5, fontWeight: FontWeight.w500, letterSpacing: -0.15, color: ink);
  static const rowSub =
      TextStyle(fontSize: 12.5, color: ink2, height: 1.4, letterSpacing: -0.05);
  static const rowValue = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: ink);
  static const caption =
      TextStyle(fontSize: 14, color: ink2, height: 1.55, letterSpacing: -0.1);
  static const axis = TextStyle(fontSize: 10, color: ink3, letterSpacing: 0.1);
  static const note =
      TextStyle(fontSize: 13, color: ink2, height: 1.6, letterSpacing: -0.05);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, surface: bg),
        splashFactory: NoSplash.splashFactory,
        highlightColor: line3,
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

/// Esikler ve etiket anahtarlari. Metin degil ANAHTAR doner; cevirisi S'ten alinir.
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
