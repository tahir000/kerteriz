import 'package:health/health.dart';

import '../config.dart';
import 'day_record.dart';

/// Health Connect'ten okuyup gunluk kayitlara ceviren katman.
/// Hicbir yere veri gondermez; her sey cihazda kalir.
class HealthRepository {
  final Health _health = Health();

  /// Son okumada Health Connect'in tip tip kac kayit dondurdugu.
  /// Bos donen bir tip, izin verilmis olsa bile o verinin hic yazilmadigini gosterir.
  Map<HealthDataType, int> rawCounts = {};
  DateTime? firstPoint;
  DateTime? lastPoint;
  int requestedDays = 0;

  /// Okumak istedigimiz tipler. Cihaz ya da Google Health bir tipi
  /// yazmiyorsa o tip bos doner; uygulama eksik tiple de calisir.
  static const List<HealthDataType> types = [
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.SKIN_TEMPERATURE,
  ];

  Future<void> configure() => _health.configure();

  Future<HealthConnectSdkStatus?> sdkStatus() => _health.getHealthConnectSdkStatus();

  Future<void> installHealthConnect() => _health.installHealthConnect();

  Future<bool> hasPermissions() async =>
      (await _health.hasPermissions(types, permissions: _readAccess(types.length))) ?? false;

  Future<bool> requestPermissions() =>
      _health.requestAuthorization(types, permissions: _readAccess(types.length));

  List<HealthDataAccess> _readAccess(int n) =>
      List<HealthDataAccess>.filled(n, HealthDataAccess.READ);

  // ------------------------------------------------------------------
  // Okuma
  // ------------------------------------------------------------------
  Future<List<DayRecord>> load({int? days}) async {
    final span = days ?? Config.historyDays;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = DateTime(now.year, now.month, now.day - span);

    const wanted = types;
    List<HealthDataPoint> points = [];
    try {
      points = await _health.getHealthDataFromTypes(
        types: wanted,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      // Bir tip desteklenmiyorsa tek tek dene, calisanlari topla.
      for (final t in wanted) {
        try {
          points.addAll(await _health.getHealthDataFromTypes(
            types: [t],
            startTime: start,
            endTime: end,
          ));
        } catch (_) {}
      }
    }
    points = _health.removeDuplicates(points);

    // --- kapsama ozeti: neyin geldigini, neyin gelmedigini kaydet ---
    requestedDays = span;
    rawCounts = {};
    firstPoint = null;
    lastPoint = null;
    for (final p in points) {
      rawCounts[p.type] = (rawCounts[p.type] ?? 0) + 1;
      if (firstPoint == null || p.dateFrom.isBefore(firstPoint!)) firstPoint = p.dateFrom;
      if (lastPoint == null || p.dateTo.isAfter(lastPoint!)) lastPoint = p.dateTo;
    }

    // Gun iskeleti: yalnizca istenen pencere kadar gun olusur.
    // Pencere disina dusen bir olcum (ornegin aksam saatindeki bir kayit)
    // yeni bir "yarin" kaydi uretmesin diye arama fonksiyonu null dondurur.
    final byDate = <String, DayRecord>{};
    for (var i = 0; i <= span; i++) {
      final d = DateTime(now.year, now.month, now.day - span + i);
      byDate[_key(d)] = DayRecord(d);
    }
    DayRecord? dayFor(DateTime d) => byDate[_key(d)];

    // --- uyku segmentleri ---
    final sleepStages = {
      HealthDataType.SLEEP_DEEP: 'deep',
      HealthDataType.SLEEP_LIGHT: 'light',
      HealthDataType.SLEEP_REM: 'rem',
      HealthDataType.SLEEP_AWAKE: 'awake',
    };
    for (final p in points) {
      final stage = sleepStages[p.type];
      if (stage == null) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      rec.segments.add(SleepSegment(stage, p.dateFrom, p.dateTo));
    }

    // Evre kaydi hic yoksa SLEEP_SESSION'dan en azindan sure cikar.
    for (final p in points) {
      if (p.type != HealthDataType.SLEEP_SESSION) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      if (rec.segments.isEmpty) {
        rec.bedStart = p.dateFrom;
        rec.wakeEnd = p.dateTo;
        rec.timeInBed = p.dateTo.difference(p.dateFrom).inMinutes;
        rec.asleep = rec.timeInBed;
        rec.light = rec.timeInBed;
      }
    }

    for (final rec in byDate.values) {
      if (rec.segments.isEmpty) continue;
      rec.segments.sort((a, b) => a.start.compareTo(b.start));
      rec.bedStart = rec.segments.first.start;
      rec.wakeEnd = rec.segments.last.end;
      rec.timeInBed = rec.wakeEnd!.difference(rec.bedStart!).inMinutes;
      for (final s in rec.segments) {
        switch (s.stage) {
          case 'deep':
            rec.deep += s.minutes;
            break;
          case 'rem':
            rec.rem += s.minutes;
            break;
          case 'light':
            rec.light += s.minutes;
            break;
          case 'awake':
            rec.awakeMinutes += s.minutes;
            rec.awakenings += 1;
            break;
        }
      }
      rec.asleep = rec.deep + rec.rem + rec.light;
      if (rec.asleep == 0) rec.asleep = rec.timeInBed - rec.awakeMinutes;
      if (rec.timeInBed < rec.asleep) rec.timeInBed = rec.asleep + rec.awakeMinutes;
    }

    // --- gece pencereli olcumler ---
    final nightly = <HealthDataType, String>{
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'hrv',
      HealthDataType.RESPIRATORY_RATE: 'resp',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
    };
    final buckets = <String, Map<String, List<double>>>{};
    for (final p in points) {
      final field = nightly[p.type];
      if (field == null && p.type != HealthDataType.SKIN_TEMPERATURE) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      final v = _num(p);
      if (v == null) continue;
      final key = _key(rec.date);
      buckets.putIfAbsent(key, () => {});
      buckets[key]!.putIfAbsent(field ?? 'temp', () => []).add(v);
    }
    buckets.forEach((key, fields) {
      final rec = byDate[key];
      if (rec == null) return;
      if (fields['hrv'] != null) rec.hrv = _mean(fields['hrv']!);
      if (fields['resp'] != null) rec.respiratory = _mean(fields['resp']!);
      if (fields['temp'] != null) rec.skinTempDelta = _mean(fields['temp']!);
      final ox = fields['spo2'];
      if (ox != null && ox.isNotEmpty) {
        rec.spo2Avg = _mean(ox);
        rec.spo2Min = ox.reduce((a, b) => a < b ? a : b);
      }
    });

    // --- dinlenme nabzi ---
    for (final p in points) {
      if (p.type != HealthDataType.RESTING_HEART_RATE) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null) continue;
      final v = _num(p);
      if (v != null) rec.rhr = v;
    }

    // --- nabiz serisi: gece egrisi + gunduz bolgeleri ---
    final hrPoints = points.where((p) => p.type == HealthDataType.HEART_RATE).toList()
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    for (final rec in byDate.values) {
      if (rec.bedStart != null && rec.wakeEnd != null) {
        final inNight = hrPoints.where((p) =>
            !p.dateFrom.isBefore(rec.bedStart!) && !p.dateFrom.isAfter(rec.wakeEnd!));
        final bins = <int, List<double>>{};
        for (final p in inNight) {
          final v = _num(p);
          if (v == null) continue;
          final m = p.dateFrom.difference(rec.bedStart!).inMinutes;
          bins.putIfAbsent((m ~/ 10) * 10, () => []).add(v);
        }
        final keys = bins.keys.toList()..sort();
        rec.nightHr = [for (final k in keys) HrSample(k, _mean(bins[k]!))];
        // RESTING_HEART_RATE kaydi gelmiyorsa gece nabiz serisinden turet.
        // Tek bir dip degeri gurultuye acik; 30 dakikalik en dusuk kararli
        // ortalamayi aliyoruz (uc adet 10 dk'lik kova).
        if (rec.rhr == null && rec.nightHr.length >= 3) {
          double best = double.infinity;
          for (var i = 0; i + 2 < rec.nightHr.length; i++) {
            final avg = (rec.nightHr[i].bpm +
                    rec.nightHr[i + 1].bpm +
                    rec.nightHr[i + 2].bpm) /
                3;
            if (avg < best) best = avg;
          }
          if (best.isFinite) {
            rec.rhr = double.parse(best.toStringAsFixed(1));
            rec.rhrDerived = true;
          }
        } else if (rec.rhr == null && rec.nightHr.isNotEmpty) {
          rec.rhr = rec.nightHr.map((s) => s.bpm).reduce((a, b) => a < b ? a : b);
          rec.rhrDerived = true;
        }
      }

      // bolgeler: gun boyu nabiz orneklerinin sureye agirlikli dagilimi
      final dayStart = rec.date;
      final dayEnd = DateTime(rec.date.year, rec.date.month, rec.date.day + 1);
      final inDay = hrPoints
          .where((p) => !p.dateFrom.isBefore(dayStart) && p.dateFrom.isBefore(dayEnd))
          .toList();
      for (var i = 0; i < inDay.length; i++) {
        final v = _num(inDay[i]);
        if (v == null) continue;
        var gap = 1.0;
        if (i + 1 < inDay.length) {
          gap = inDay[i + 1]
              .dateFrom
              .difference(inDay[i].dateFrom)
              .inSeconds
              .toDouble() /
              60.0;
        }
        if (gap <= 0 || gap > 2) gap = 1.0; // uzun bosluklari sayma
        final rest = rec.rhr ?? 60;
        final hrr = (v - rest) / (Config.hrMax - rest);
        if (hrr >= 0.85) {
          rec.zoneMinutes[4] += gap;
        } else if (hrr >= 0.70) {
          rec.zoneMinutes[3] += gap;
        } else if (hrr >= 0.60) {
          rec.zoneMinutes[2] += gap;
        } else if (hrr >= 0.50) {
          rec.zoneMinutes[1] += gap;
        }
      }
    }

    // --- adim ---
    for (final rec in byDate.values) {
      try {
        final s = await _health.getTotalStepsInInterval(rec.date,
            DateTime(rec.date.year, rec.date.month, rec.date.day + 1));
        rec.steps = s ?? 0;
      } catch (_) {
        rec.steps = 0;
      }
    }

    final list = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ------------------------------------------------------------------
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sabah 18:00'dan once biten uyku, bittigi takvim gunune yazilir.
  static DateTime _sleepDay(DateTime end) {
    final d = end.hour < 18 ? end : end.add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day);
  }

  static double? _num(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  static double _mean(List<double> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length;
}
