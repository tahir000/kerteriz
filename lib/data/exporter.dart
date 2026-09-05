import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../metrics/engine.dart';
import 'day_record.dart';

/// Ham + turetilmis veriyi tek bir JSON dosyasina yazip paylasir.
/// Dosya cihazda uretilir; nereye gidecegine kullanici karar verir.
class Exporter {
  static Future<File> write(List<DayRecord> days) async {
    final payload = {
      'app': 'kerteriz',
      'schema': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'config': {
        'age': Config.age,
        'hrMax': Config.hrMax,
        'baselineWindow': Config.baselineWindow,
        'sleepNeedBaseMinutes': Config.sleepNeedBaseMinutes,
      },
      'summary': {
        'days': days.length,
        'sri30': MetricsEngine.sri(days),
        'illnessSignal': MetricsEngine.illnessSignal(days),
        'overloadSignal': MetricsEngine.overloadSignal(days),
        'coverage': {
          'sleep': days.where((d) => d.hasSleep).length,
          'hrv': days.where((d) => d.hrv != null).length,
          'rhr': days.where((d) => d.rhr != null).length,
          'spo2': days.where((d) => d.spo2Avg != null).length,
          'respiratory': days.where((d) => d.respiratory != null).length,
          'skinTemperature': days.where((d) => d.skinTempDelta != null).length,
        },
      },
      'days': days.map((d) => d.toJson()).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/kerteriz-$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  static Future<void> share(List<DayRecord> days,
      {String subject = 'Kerteriz data export'}) async {
    final file = await write(days);
    // share_plus 13: statik Share.shareXFiles yerine SharePlus.instance.share
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: subject,
      text: subject,
    ));
  }
}
