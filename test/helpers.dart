import 'package:kerteriz/data/day_record.dart';

/// Test için sentetik gün. Varsayılanlar "sıradan iyi bir gece":
/// 23:00 yatış, 8 saat 40 dk yatakta, 8 saat uyku.
DayRecord gun(
  DateTime date, {
  int asleep = 480,
  int timeInBed = 520,
  int deep = 90,
  int rem = 110,
  int awakenings = 2,
  int awakeMinutes = 20,
  double? hrv = 50,
  double? rhr = 55,
  int steps = 8000,
  List<double>? zoneMinutes,
  int bedHour = 23,
  int hydrationMl = 0,
  List<HrSample>? nightHr,
}) {
  final d = DayRecord(date);
  d.asleep = asleep;
  d.timeInBed = asleep == 0 ? 0 : timeInBed;
  d.deep = asleep == 0 ? 0 : deep;
  d.rem = asleep == 0 ? 0 : rem;
  d.light = asleep == 0 ? 0 : asleep - deep - rem;
  d.awakenings = awakenings;
  d.awakeMinutes = awakeMinutes;
  d.hrv = hrv;
  d.rhr = rhr;
  d.steps = steps;
  d.hydrationMl = hydrationMl;
  if (zoneMinutes != null) d.zoneMinutes = zoneMinutes;
  if (asleep > 0) {
    d.bedStart = DateTime(date.year, date.month, date.day - 1, bedHour);
    d.wakeEnd = d.bedStart!.add(Duration(minutes: timeInBed));
  }
  if (nightHr != null) d.nightHr = nightHr;
  return d;
}

/// [n] ardışık gün, [son] dahil geriye doğru. [f] her güne müdahale eder.
List<DayRecord> gunler(int n,
    {DateTime? son, DayRecord Function(DateTime date, int i)? f}) {
  final s = son ?? DateTime(2026, 10, 7);
  return [
    for (var i = 0; i < n; i++)
      (f ?? (date, _) => gun(date))(
          DateTime(s.year, s.month, s.day - (n - 1 - i)), i),
  ];
}
