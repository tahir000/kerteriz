import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../metrics/insights.dart';
import 'day_record.dart';

/// Uygulamanın içinden işaretlenen regl günleri.
///
/// Ayrı bir regl uygulaması kullanmayanlar için: Döngü sekmesindeki takvimden
/// günler işaretleniyor. Health Connect'e yazılmıyor (uygulamanın tek yazma
/// izni su); etiket günlüğü gibi telefondaki küçük bir JSON dosyasında
/// duruyor. Health Connect'ten gelen kayıtlarla birleştiriliyor: ikisinden
/// birinde regl olan gün regl sayılıyor.
class ReglKayitlari {
  static const String dosyaAdi = 'kerteriz_regl.json';

  static final Set<String> gunler = {};
  static final ValueNotifier<int> degisti = ValueNotifier<int>(0);

  static bool varMi(DateTime d) => gunler.contains(gunAnahtari(d));

  /// Yerel kayıtları günlere işler: Health Connect'ten gelen ya da burada
  /// işaretlenen gün regl. İşaret kaldırılınca gün Health Connect'teki
  /// haline döner.
  static void uygula(List<DayRecord> days) {
    for (final d in days) {
      d.regl = d.reglHc || gunler.contains(gunAnahtari(d.date));
    }
  }

  static Future<File> _dosya() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
  }

  static Future<void> oku() async {
    try {
      final f = await _dosya();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map || m['gunler'] is! List) return;
      gunler
        ..clear()
        ..addAll((m['gunler'] as List).whereType<String>());
      degisti.value++;
    } catch (_) {}
  }

  static Future<void> degistir(DateTime d) async {
    final k = gunAnahtari(d);
    if (!gunler.remove(k)) gunler.add(k);
    degisti.value++;
    await _kaydet();
  }

  static Future<void> _sira = Future<void>.value();

  static Future<void> _kaydet() =>
      _sira = _sira.then((_) => _diskeYaz()).catchError((_) {});

  static Future<void> _diskeYaz() async {
    try {
      final f = await _dosya();
      await f.writeAsString(
          jsonEncode({'schema': 1, 'gunler': gunler.toList()..sort()}));
    } catch (_) {}
  }
}
