// Dışa aktarılmış veriyle motorun dağılımlarına bakan araç.
//
//   dart run tool/kalibre.dart kerteriz-2026-10-07.json
//
// Uygulamadan "Veriyi dışa aktar" ile alınan JSON'u okur, uyku bloklarını
// yeniden ayırır, motoru baştan çalıştırır ve eşik ayarı için gereken
// dağılımları yazar. Veri dosyası depoya girmez (.gitignore).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:intl/date_symbol_data_local.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/data/uyku_bloklari.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/metrics/insights.dart';

double yuzdelik(List<double> a, double p) {
  final s = [...a]..sort();
  if (s.isEmpty) return double.nan;
  final k = (s.length - 1) * p;
  final f = k.floor(), c = k.ceil();
  return f == c ? s[f] : s[f] + (s[c] - s[f]) * (k - f);
}

String dagilim(String ad, List<double> a, {int ondalik = 0}) {
  String f(double x) => x.toStringAsFixed(ondalik);
  return '${ad.padRight(26)} n=${a.length.toString().padLeft(2)}  '
      'en az ${f(a.reduce(math.min))}  p25 ${f(yuzdelik(a, .25))}  '
      'medyan ${f(yuzdelik(a, .5))}  p75 ${f(yuzdelik(a, .75))}  '
      'en çok ${f(a.reduce(math.max))}';
}

Future<void> main(List<String> args) async {
  await initializeDateFormatting('tr');
  DayRecord.locale = 'tr';
  final j = jsonDecode(File(args.first).readAsStringSync()) as Map;
  final days = [
    for (final m in j['days'] as List) DayRecord.fromJson(m as Map<String, dynamic>)
  ];
  final eskiSkor = {for (final d in days) d.date: d.sleepScore};
  final eskiYatak = {for (final d in days) d.date: d.timeInBed};

  for (final d in days) {
    uykuyuTopla(d);
  }
  MetricsEngine.run(days);
  final uyku = days.where((d) => d.hasSleep).toList();

  stdout.writeln('--- şekerleme ayrımının etkisi ---');
  for (final d in uyku) {
    if (d.napMinutes > 0 || eskiYatak[d.date] != d.timeInBed) {
      stdout.writeln('${d.label.padRight(8)} yatakta ${eskiYatak[d.date]} -> '
          '${d.timeInBed} dk, şekerleme ${d.napMinutes} dk, uyku skoru '
          '${eskiSkor[d.date]} -> ${d.sleepScore}');
    }
  }

  stdout.writeln('\n--- dağılımlar (düzeltilmiş) ---');
  stdout.writeln(dagilim('gece uykusu (dk)', [for (final d in uyku) d.asleep.toDouble()]));
  stdout.writeln(dagilim('uyku + şekerleme (dk)',
      [for (final d in uyku) (d.asleep + d.napMinutes).toDouble()]));
  stdout.writeln(dagilim('verim', [for (final d in uyku) d.asleep / d.timeInBed], ondalik: 3));
  stdout.writeln(dagilim('derin+REM oranı',
      [for (final d in uyku) (d.deep + d.rem) / d.asleep], ondalik: 3));
  final mids = [for (final d in uyku) d.sleepMidpoint!];
  final ortMid = MetricsEngine.mean(mids);
  stdout.writeln(dagilim('orta nokta sapması (dk)', [for (final m in mids) (m - ortMid).abs()]));
  stdout.writeln(dagilim('uyanma sayısı', [for (final d in uyku) d.awakenings.toDouble()]));
  stdout.writeln(dagilim('uyanık dk', [for (final d in uyku) d.awakeMinutes.toDouble()]));
  for (final p in ['Sure', 'Verim', 'Onarim', 'Kesintisizlik', 'Zamanlama']) {
    stdout.writeln(dagilim('bileşen: $p', [for (final d in uyku) d.sleepParts[p] ?? 0]));
  }
  stdout.writeln(dagilim('uyku skoru', [for (final d in uyku) d.sleepScore.toDouble()]));
  final kal = days.where((d) => d.baselineNights >= 7).toList();
  stdout.writeln(dagilim('hazırlık (kalibre)', [for (final d in kal) d.readiness.toDouble()]));
  stdout.writeln(dagilim('uyku borcu (dk)', [for (final d in days) d.debtMinutes.toDouble()]));
  stdout.writeln(dagilim('günlük yük', [for (final d in days) d.strain]));
  stdout.writeln(dagilim('kardiyak', [for (final d in days) d.cardiac.toDouble()]));
  stdout.writeln(dagilim('HRV (ms)', [for (final d in days) if (d.hrv != null) d.hrv!]));
  stdout.writeln(dagilim('dinlenme nabzı', [for (final d in days) if (d.rhr != null) d.rhr!]));
  stdout.writeln(dagilim('solunum', [for (final d in days) if (d.respiratory != null) d.respiratory!], ondalik: 1));
  stdout.writeln('SRI (30 gün): ${MetricsEngine.sri(days)}');

  stdout.writeln('\n--- son günlerde sinyaller ---');
  for (var n = days.length - 6; n <= days.length; n++) {
    final w = days.sublist(0, n);
    final g = Insights.elevatedNightHr(w);
    stdout.writeln('${w.last.label.padRight(8)} nabız ${w.last.rhr?.toStringAsFixed(0)} '
        '(taban ${w.last.rhrBaseline?.toStringAsFixed(1)}, z ${w.last.rhrZ.toStringAsFixed(1)}) '
        'solunum z ${w.last.respZ.toStringAsFixed(1)} · hastalık: ${MetricsEngine.illnessSignal(w)} '
        '· gece nabzı: ${g == null ? '-' : '+${g.deltaBpm.toStringAsFixed(1)}'}');
  }
}
