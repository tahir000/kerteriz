import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'day_record.dart';

/// Ana ekran özet widget'ı için küçük bir özet dosyası yazar.
///
/// Widget Kotlin tarafında çalışıyor ve Dart'taki metrik motoruna erişemiyor:
/// hazırlık, uyku skoru ve dinlenme nabzı 14 günlük taban çizgiye dayanan
/// türetilmiş değerler, widget'ın kendi başına hesaplaması mümkün değil.
/// Bu dosya ikisi arasındaki tek köprü.
///
/// `getApplicationSupportDirectory()` Android'de `context.filesDir` ile aynı
/// klasördür; Kotlin tarafı dosyayı oradan okuyor. Uygulamanın kendi özel
/// alanı, dışarıdan erişilemez.
class OzetYazici {
  static const String dosyaAdi = 'kerteriz_ozet.json';

  /// Her okumadan sonra çağrılır. Hata verirse yutulur: özet dosyası
  /// yazılamadığında widget boş gösterir, uygulama çalışmaya devam eder.
  static Future<void> yaz(List<DayRecord> days) async {
    if (days.isEmpty) return;
    final d = days.last;
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
    // Skorlar hesaplanamadıysa sıfır yazmak yerine null yazıyoruz: widget
    // "0 hazırlık" ile "hazırlık yok" arasındaki farkı ancak böyle görebilir.
    final hesaplandi = d.readiness > 0;
    await f.writeAsString(jsonEncode({
      'schema': 1,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'date': d.date.toIso8601String(),
      'readiness': hesaplandi ? d.readiness : null,
      'sleepScore': d.sleepScore > 0 ? d.sleepScore : null,
      'sleepMinutes': d.asleep > 0 ? d.asleep.round() : null,
      'rhr': d.rhr,
    }));
  }
}
