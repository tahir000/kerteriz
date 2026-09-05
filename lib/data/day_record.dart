import 'package:intl/intl.dart';

class HrSample {
  final int minute; // gecenin basindan itibaren dakika
  final double bpm;
  const HrSample(this.minute, this.bpm);
  Map<String, dynamic> toJson() => {'m': minute, 'v': bpm};
}

class SleepSegment {
  final String stage; // deep | light | rem | awake
  final DateTime start;
  final DateTime end;
  const SleepSegment(this.stage, this.start, this.end);
  int get minutes => end.difference(start).inMinutes;
  Map<String, dynamic> toJson() => {
        'stage': stage,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
}

/// Bir "gun" = o sabah biten gece + o gunun aktivitesi.
class DayRecord {
  final DateTime date; // uyanilan takvim gunu (yerel, gece yarisi)

  // --- ham ---
  DateTime? bedStart;
  DateTime? wakeEnd;
  int timeInBed = 0;
  int asleep = 0;
  int deep = 0;
  int rem = 0;
  int light = 0;
  int awakeMinutes = 0;
  int awakenings = 0;
  List<SleepSegment> segments = [];
  List<HrSample> nightHr = [];

  double? hrv; // RMSSD, ms
  double? rhr; // atim/dk
  bool rhrDerived = false; // kayit yoktu, gece nabiz serisinden turetildi
  double? respiratory; // soluk/dk
  double? skinTempDelta; // C
  double? spo2Avg;
  double? spo2Min;
  int steps = 0;
  List<double> zoneMinutes = [0, 0, 0, 0, 0]; // 0 kullanilmiyor, 1..4

  // --- turetilmis (engine dolduruyor) ---
  double hrvZ = 0, rhrZ = 0, respZ = 0, tempZ = 0;
  double? hrvBaseline, hrvBaselineSd, rhrBaseline;
  double strainRaw = 0, strain = 0;
  int need = 0;
  int sleepScore = 0;
  Map<String, double> sleepParts = {};
  int readiness = 0;
  int debtMinutes = 0;
  double acute = 0, chronic = 0, acwr = 1;
  int cardiac = 0;
  double? nadirBpm;
  int? nadirMinute;

  DayRecord(this.date);

  bool get hasSleep => asleep > 0;

  /// 20:00'dan itibaren dakika cinsinden yatis ani (raster ve zamanlama icin).
  double? get bedOffset {
    if (bedStart == null) return null;
    final anchor = DateTime(date.year, date.month, date.day - 1, 20);
    return bedStart!.difference(anchor).inMinutes.toDouble();
  }

  double? get sleepMidpoint {
    final b = bedOffset;
    if (b == null) return null;
    return b + timeInBed / 2;
  }

  /// Etiketlerin dili. Uygulama acilirken cihaz diline gore ayarlanir.
  static String locale = 'en';

  String get label => DateFormat('d MMM', locale).format(date);

  Map<String, dynamic> toJson() => {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'bedStart': bedStart?.toIso8601String(),
        'wakeEnd': wakeEnd?.toIso8601String(),
        'timeInBed': timeInBed,
        'asleep': asleep,
        'deep': deep,
        'rem': rem,
        'light': light,
        'awakeMinutes': awakeMinutes,
        'awakenings': awakenings,
        'hrv': hrv,
        'rhr': rhr,
        'rhrDerived': rhrDerived,
        'respiratory': respiratory,
        'skinTempDelta': skinTempDelta,
        'spo2Avg': spo2Avg,
        'spo2Min': spo2Min,
        'steps': steps,
        'zoneMinutes': zoneMinutes,
        'segments': segments.map((s) => s.toJson()).toList(),
        'nightHr': nightHr.map((s) => s.toJson()).toList(),
        'derived': {
          'hrvZ': hrvZ,
          'rhrZ': rhrZ,
          'respZ': respZ,
          'tempZ': tempZ,
          'strain': strain,
          'need': need,
          'sleepScore': sleepScore,
          'sleepParts': sleepParts,
          'readiness': readiness,
          'debtMinutes': debtMinutes,
          'acute': acute,
          'chronic': chronic,
          'acwr': acwr,
          'cardiac': cardiac,
          'nadirBpm': nadirBpm,
          'nadirMinute': nadirMinute,
        },
      };
}
