import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../metrics/insights.dart';

/// Sabah değerlendirmesi: "Bugün nasıl hissediyorsun?" 1-5.
///
/// Skoru doğrulamanın tek yolu kişinin kendi hissi. "Senin verin ne diyor"
/// ekranı ikisini karşılaştırıyor: iyi hissettiğin sabahlar hazırlık da
/// yüksek mi? Etiket günlüğüyle aynı düz JSON yöntemi; anahtar sabahın
/// takvim günü.
class Hisler {
  static const String dosyaAdi = 'kerteriz_hisler.json';

  /// 1 çok yorgun ... 5 çok iyi.
  static const int enAz = 1, enCok = 5;

  static final Map<String, int> kayit = {};
  static final ValueNotifier<int> degisti = ValueNotifier<int>(0);

  static int? bugun([DateTime? simdi]) =>
      kayit[gunAnahtari(simdi ?? DateTime.now())];

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
        if (k is String && v is int && v >= enAz && v <= enCok) kayit[k] = v;
      });
      degisti.value++;
    } catch (_) {
      // Bozuk dosya: boş kayıtla devam.
    }
  }

  static Future<void> yaz(int deger, [DateTime? simdi]) async {
    kayit[gunAnahtari(simdi ?? DateTime.now())] = deger.clamp(enAz, enCok);
    degisti.value++;
    await _kaydet();
  }

  static Future<void> _sira = Future<void>.value();

  static Future<void> _kaydet() =>
      _sira = _sira.then((_) => _diskeYaz()).catchError((_) {});

  static Future<void> _diskeYaz() async {
    try {
      final f = await _dosya();
      await f.writeAsString(jsonEncode({'schema': 1, 'gunler': kayit}));
    } catch (_) {}
  }
}
