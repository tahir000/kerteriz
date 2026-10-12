import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../metrics/engine.dart';
import 'ayarlar.dart';
import 'day_record.dart';

/// Ham + türetilmiş veriyi tek bir JSON dosyasına yazıp paylaşır.
/// Dosya cihazda üretilir; nereye gideceğine kullanıcı karar verir.
class Exporter {
  static Future<File> write(List<DayRecord> days) async {
    final payload = {
      'app': 'kerteriz',
      'schema': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'config': {
        'age': Ayarlar.yas,
        'hrMax': Ayarlar.hrMax,
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

    // Önbellek klasörü: Android yedeğine girmiyor ve sistem gerektiğinde
    // kendisi temizliyor. Her yeni dışa aktarım öncekileri siliyor; tam
    // sağlık dökümü telefonda birikmesin.
    final dir = await _klasor();
    await _eskileriSil(dir);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/kerteriz-$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  static Future<Directory> _klasor() async {
    final d = Directory('${(await getTemporaryDirectory()).path}/disa_aktarim');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<void> _eskileriSil(Directory d) async {
    await for (final f in d.list()) {
      if (f is File) await f.delete().catchError((_) => f);
    }
  }

  /// Açılışta çağrılır. Bir saatten eski dışa aktarımları ve 0.17'ye kadar
  /// kalıcı klasöre yazılmış eski dosyaları siler. Paylaşım hemen
  /// silinmiyor: alıcı uygulama (Drive, e-posta) dosyayı okumayı paylaşım
  /// ekranı kapandıktan sonra da sürdürebiliyor.
  static Future<void> temizle() async {
    try {
      final eski = await getApplicationDocumentsDirectory();
      await for (final f in eski.list()) {
        final ad = f.uri.pathSegments.last;
        if (f is File && ad.startsWith('kerteriz-') && ad.endsWith('.json')) {
          await f.delete();
        }
      }
      final d = await _klasor();
      final sinir = DateTime.now().subtract(const Duration(hours: 1));
      await for (final f in d.list()) {
        if (f is File && (await f.lastModified()).isBefore(sinir)) {
          await f.delete();
        }
      }
    } catch (_) {
      // Temizlenemezse bir sonraki açılışta yeniden denenir.
    }
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
