import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../metrics/insights.dart';

/// Etiket günlüğü: "bu akşam alkol vardı" gibi tek dokunuşluk işaretler.
///
/// Health Connect'te karşılığı olmadığı için su gibi oraya yazılamıyor;
/// [Ayarlar] ile aynı düz JSON yöntemi. Anahtar akşamın takvim günü
/// (`2026-10-07`), değer o akşamın etiketleri. Anahtarın var olması "o akşam
/// günlüğe bakıldı" demek; boş liste "hiçbiri" demek. Karşılaştırma yalnızca
/// bakılmış akşamları sayıyor, bu yüzden ikisi ayrı tutuluyor.
class Etiketler {
  static const String dosyaAdi = 'kerteriz_etiketler.json';

  /// Gece yarısından sonra bu saate kadar açılan uygulama hala "dün akşam"
  /// sayılır: 01:00'de "alkol" işaretleyen kişi bu sabahı değil, birazdan
  /// başlayacak geceyi kastediyor.
  static const int aksamBitisSaati = 5;

  static final Map<String, Set<String>> kayit = {};

  /// Her değişiklikte artar; arayüz dinliyor.
  static final ValueNotifier<int> degisti = ValueNotifier<int>(0);

  /// Etiketlenecek akşamın günü.
  static DateTime aksam([DateTime? simdi]) {
    final n = simdi ?? DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return n.hour < aksamBitisSaati
        ? DateTime(d.year, d.month, d.day - 1)
        : d;
  }

  static Set<String>? bugun() => kayit[gunAnahtari(aksam())];

  static Future<File> _dosya() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
  }

  static Future<void> oku() async {
    try {
      final f = await _dosya();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map || m['gunler'] is! Map) return;
      kayit.clear();
      (m['gunler'] as Map).forEach((k, v) {
        if (k is String && v is List) {
          kayit[k] = v.whereType<String>().where(etiketListesi.contains).toSet();
        }
      });
      degisti.value++;
    } catch (_) {
      // Bozuk dosya: boş günlükle devam.
    }
  }

  /// Bu akşam için etiketi açar ya da kapatır.
  static Future<void> degistir(String etiket) async {
    final k = gunAnahtari(aksam());
    final s = kayit.putIfAbsent(k, () => <String>{});
    if (!s.remove(etiket)) s.add(etiket);
    degisti.value++;
    await _kaydet();
  }

  /// "Hiçbiri": akşamı etiketsiz ama bakılmış olarak işaretler.
  static Future<void> hicbiri() async {
    kayit[gunAnahtari(aksam())] = <String>{};
    degisti.value++;
    await _kaydet();
  }

  // Ayarlar'daki gibi yazımlar sıraya alınıyor: hızlı dokunuşlarda iki yazım
  // çakışıp dosyayı bozmasın.
  static Future<void> _sira = Future<void>.value();

  static Future<void> _kaydet() =>
      _sira = _sira.then((_) => _diskeYaz()).catchError((_) {});

  static Future<void> _diskeYaz() async {
    try {
      final f = await _dosya();
      await f.writeAsString(jsonEncode({
        'schema': 1,
        'gunler': {
          for (final e in kayit.entries) e.key: (e.value.toList()..sort()),
        },
      }));
    } catch (_) {
      // Yazılamadıysa seçim bu oturum boyunca geçerli kalır.
    }
  }
}
