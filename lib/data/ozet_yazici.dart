import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ayarlar.dart';
import 'day_record.dart';

/// Ana ekran widget'larının okuduğu küçük köprü dosyası.
///
/// İki iş görür:
///
///  1. **Türetilmiş skorlar.** Hazırlık, uyku skoru ve dinlenme nabzı 14
///     günlük taban çizgiye dayanır; motor Dart tarafında çalışıyor ve
///     Kotlin oraya erişemiyor. Uygulama her okumadan sonra buraya yazıyor.
///  2. **Hedefler.** Adım, kalori, mesafe ve su hedefleri artık koda gömülü
///     değil, kullanıcının ayarlardan seçtiği değerler. Widget'lar hedefi
///     buradan okuyor; dosya yoksa derlemeye gömülü varsayılana düşüyorlar.
///
/// `getApplicationSupportDirectory()` Android'de `context.filesDir` ile aynı
/// klasördür. Uygulamanın kendi özel alanı, dışarıdan erişilemez.
class OzetYazici {
  static const String dosyaAdi = 'kerteriz_ozet.json';

  /// Her okumadan sonra çağrılır. Hata verirse yutulur: özet dosyası
  /// yazılamadığında widget boş gösterir, uygulama çalışmaya devam eder.
  ///
  /// Gün listesi boş olsa bile dosya yazılır: hedefler skorlardan bağımsız,
  /// widget'ın onlara her durumda ihtiyacı var.
  static Future<void> yaz(List<DayRecord> days) async {
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
    final d = days.isEmpty ? null : days.last;

    // Skorlar hesaplanamadıysa sıfır yazmak yerine null yazıyoruz: widget
    // "0 hazırlık" ile "hazırlık yok" arasındaki farkı ancak böyle görebilir.
    final hesaplandi = d != null && d.readiness > 0;
    await f.writeAsString(jsonEncode({
      'schema': 2,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'date': d?.date.toIso8601String(),
      'readiness': hesaplandi ? d.readiness : null,
      'sleepScore': (d != null && d.sleepScore > 0) ? d.sleepScore : null,
      'sleepMinutes': (d != null && d.asleep > 0) ? d.asleep.round() : null,
      'rhr': d?.rhr,
      'hedefler': {
        'su': Ayarlar.suHedefiMl,
        'suPorsiyon': Ayarlar.suPorsiyonMl,
        'adim': Ayarlar.adimHedefi,
        'kalori': Ayarlar.kaloriHedefi,
        'kaloriAktif': Ayarlar.aktifKaloriHedefi,
        'mesafeOndaKm': Ayarlar.mesafeHedefiOndaKm,
      },
    }));
  }
}
