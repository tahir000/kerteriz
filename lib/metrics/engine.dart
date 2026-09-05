import 'dart:math' as math;

import '../config.dart';
import '../data/day_record.dart';

/// Ham gunluk kayitlari bilesik metriklere ceviren motor.
/// Formuller prototipteki ile birebir ayni.
class MetricsEngine {
  static double clamp(double x, double a, double b) => x < a ? a : (x > b ? b : x);

  static double mean(List<double> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length;

  static double sd(List<double> a) {
    if (a.length < 2) return 0;
    final m = mean(a);
    return math.sqrt(mean(a.map((x) => (x - m) * (x - m)).toList()) + 1e-9);
  }

  /// z-skoru: onceki [win] gunun ortalamasina gore konum.
  /// [log] true ise ln donusumu uzerinde (HRV log-normal dagilir).
  static double _z(
    List<DayRecord> days,
    int i,
    double? Function(DayRecord) get, {
    int win = Config.baselineWindow,
    bool log = false,
  }) {
    final prev = <double>[];
    for (var j = math.max(0, i - win); j < i; j++) {
      final v = get(days[j]);
      if (v == null || (log && v <= 0)) continue;
      prev.add(log ? math.log(v) : v);
    }
    final cur = get(days[i]);
    if (cur == null || prev.length < 3) return 0;
    final s = sd(prev);
    if (s < 1e-6) return 0;
    final x = log ? math.log(cur) : cur;
    return clamp((x - mean(prev)) / s, -3.5, 3.5);
  }

  /// z-skorunu 0..1 araligina tasir.
  static double nz(double z) => clamp(0.5 + z / 3.6, 0, 1);

  static void run(List<DayRecord> days) {
    for (var i = 0; i < days.length; i++) {
      final d = days[i];

      d.hrvZ = _z(days, i, (x) => x.hrv, log: true);
      d.rhrZ = _z(days, i, (x) => x.rhr);
      d.respZ = _z(days, i, (x) => x.respiratory);
      d.tempZ = _z(days, i, (x) => x.skinTempDelta == null ? null : x.skinTempDelta! + 5);

      final hrvPrev = <double>[];
      for (var j = math.max(0, i - Config.baselineWindow); j < i; j++) {
        final v = days[j].hrv;
        if (v != null && v > 0) hrvPrev.add(math.log(v));
      }
      if (hrvPrev.length >= 3) {
        d.hrvBaseline = math.exp(mean(hrvPrev));
        d.hrvBaselineSd = sd(hrvPrev);
      }
      final rhrPrev = <double>[];
      for (var j = math.max(0, i - Config.baselineWindow); j < i; j++) {
        final v = days[j].rhr;
        if (v != null) rhrPrev.add(v);
      }
      if (rhrPrev.length >= 3) d.rhrBaseline = mean(rhrPrev);

      // ---- gunluk yuk (TRIMP benzeri, log olcek) ----
      const w = [0.0, 1.00, 1.85, 2.90, 4.60];
      var raw = 0.0;
      for (var k = 1; k < 5; k++) {
        raw += d.zoneMinutes[k] * w[k];
      }
      raw += d.steps * 0.0022;
      d.strainRaw = raw;
      d.strain = clamp(6.9 * math.log(1 + raw / 24), 0, 21);

      // ---- uyku ihtiyaci ----
      final prevStrain = i > 0 ? days[i - 1].strain : 12.0;
      d.need = (Config.sleepNeedBaseMinutes + prevStrain * 2.2).round();

      // ---- uyku skoru ----
      if (d.hasSleep) {
        final cSure = clamp(d.asleep / d.need, 0, 1) * 100;
        final eff = d.timeInBed == 0 ? 0.0 : d.asleep / d.timeInBed;
        final cVerim = clamp((eff - 0.78) / 0.17, 0, 1) * 100;
        final restorative = d.asleep == 0 ? 0.0 : (d.deep + d.rem) / d.asleep;
        final cOnarim = clamp(restorative / 0.42, 0, 1) * 100;
        final cKesinti =
            clamp(100 - d.awakenings * 4.5 - d.awakeMinutes * 0.55, 0, 100);

        final mids = <double>[];
        for (var j = math.max(0, i - 21); j < i; j++) {
          final m = days[j].sleepMidpoint;
          if (m != null) mids.add(m);
        }
        final mid = d.sleepMidpoint;
        final cZaman = (mid == null || mids.isEmpty)
            ? 100.0
            : clamp(100 - (mid - mean(mids)).abs() * 1.05, 0, 100);

        d.sleepParts = {
          'Sure': cSure,
          'Verim': cVerim,
          'Onarim': cOnarim,
          'Kesintisizlik': cKesinti,
          'Zamanlama': cZaman,
        };
        d.sleepScore = (cSure * 0.35 +
                cVerim * 0.20 +
                cOnarim * 0.25 +
                cKesinti * 0.10 +
                cZaman * 0.10)
            .round();
      }

      // ---- gece kardiyak toparlanma ----
      if (d.nightHr.length > 4 && d.timeInBed > 0) {
        var nadir = d.nightHr.first;
        for (final s in d.nightHr) {
          if (s.bpm < nadir.bpm) nadir = s;
        }
        d.nadirBpm = nadir.bpm;
        d.nadirMinute = nadir.minute;
        final first = d.nightHr.first.bpm;
        final drop = first == 0 ? 0.0 : (first - nadir.bpm) / first;
        final f = nadir.minute / d.timeInBed;
        d.cardiac = (100 *
                clamp(0.55 * clamp(drop / 0.16, 0, 1) +
                        0.45 * clamp((0.72 - f) / 0.42, 0, 1),
                    0, 1))
            .round();
      }

      // ---- hazirlik: eksik girdinin agirligi otekilere dagitilir ----
      final weights = <double>[];
      final values = <double>[];
      void add(double weight, double? value) {
        if (value == null) return;
        weights.add(weight);
        values.add(value);
      }

      add(0.40, d.hrv == null ? null : nz(d.hrvZ));
      add(0.25, d.rhr == null ? null : nz(-d.rhrZ));
      add(0.25, d.hasSleep ? d.sleepScore / 100 : null);
      add(
          0.10,
          (d.respiratory == null && d.skinTempDelta == null)
              ? null
              : nz(-(d.respZ + d.tempZ) / 2));

      if (weights.isEmpty) {
        d.readiness = 0;
      } else {
        final total = weights.reduce((a, b) => a + b);
        var acc = 0.0;
        for (var k = 0; k < weights.length; k++) {
          acc += (weights[k] / total) * values[k];
        }
        d.readiness = (clamp(acc, 0, 1) * 100).round();
      }
    }

    // ---- uyku borcu: 14 gun, gunde %7 sonumleme ----
    for (var i = 0; i < days.length; i++) {
      var debt = 0.0;
      for (var j = math.max(0, i - 13); j <= i; j++) {
        final gap = days[j].need - days[j].asleep;
        if (gap > 0 && days[j].hasSleep) {
          debt += gap * math.pow(0.93, i - j).toDouble();
        }
      }
      days[i].debtMinutes = debt.round();
    }

    // ---- akut / kronik yuk ----
    for (var i = 0; i < days.length; i++) {
      final a = <double>[];
      for (var j = math.max(0, i - 6); j <= i; j++) {
        a.add(days[j].strain);
      }
      final c = <double>[];
      for (var j = math.max(0, i - 27); j <= i; j++) {
        c.add(days[j].strain);
      }
      days[i].acute = mean(a);
      days[i].chronic = mean(c);
      days[i].acwr =
          days[i].chronic < 0.1 ? 1.0 : days[i].acute / days[i].chronic;
    }
  }

  /// Sleep Regularity Index — ardisik gunlerde uyku/uyanik durumu ortusmesi.
  static int sri(List<DayRecord> days, {int window = 30}) {
    List<int> mask(DayRecord d) {
      final m = List<int>.filled(144, 0);
      final b = d.bedOffset;
      if (b == null || d.timeInBed <= 0) return m;
      final s = ((480 + b) / 10).round();
      final e = ((480 + b + d.timeInBed) / 10).round();
      for (var k = math.max(0, s); k < math.min(e, 144); k++) {
        m[k] = 1;
      }
      return m;
    }

    var match = 0, total = 0;
    final from = math.max(1, days.length - window);
    for (var i = from; i < days.length - 1; i++) {
      if (!days[i].hasSleep || !days[i + 1].hasSleep) continue;
      final a = mask(days[i]);
      final b = mask(days[i + 1]);
      for (var k = 0; k < 144; k++) {
        total++;
        if (a[k] == b[k]) match++;
      }
    }
    return total == 0 ? 0 : (100 * match / total).round();
  }

  /// Hastalik erken uyarisi: solunum + cilt sicakligi + nabiz birlikte yukselmis mi.
  static bool illnessSignal(List<DayRecord> days) {
    final w = days.length < 3 ? days : days.sublist(days.length - 3);
    final hit = w.where((d) => d.respZ > 1.2 && d.tempZ > 1.0 && d.rhrZ > 0.8).length;
    return hit >= 2;
  }

  static bool overloadSignal(List<DayRecord> days) {
    if (days.isEmpty) return false;
    final w = days.length < 3 ? days : days.sublist(days.length - 3);
    return days.last.acwr > 1.45 && w.every((d) => d.hrvZ < 0);
  }
}
