import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// Kullanıcının uygulama içi seçimlerini tutan küçük dosya.
///
/// `shared_preferences` yerine düz JSON: projede zaten `path_provider` var,
/// yeni bir paket eklemeye değmiyor. Dosya [OzetYazici] ile aynı klasörde
/// (Android'de `context.filesDir`) durur.
///
/// [tema] bir [ValueNotifier]: değiştiği anda [KerterizApp] yeniden kurulur.
class Ayarlar {
  static const String dosyaAdi = 'kerteriz_ayarlar.json';

  static final ValueNotifier<TemaTercihi> tema =
      ValueNotifier<TemaTercihi>(TemaTercihi.sistem);

  static Future<File> _dosya() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
  }

  /// Açılışta bir kez çağrılır. Dosya yoksa ya da bozuksa varsayılanla
  /// devam eder: ayar okunamaması uygulamayı durdurmaz.
  static Future<void> oku() async {
    try {
      final f = await _dosya();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map) return;
      final ad = m['tema'];
      if (ad is String) {
        tema.value = TemaTercihi.values.firstWhere(
          (t) => t.name == ad,
          orElse: () => TemaTercihi.sistem,
        );
      }
    } catch (_) {
      // Bozuk dosya: varsayılanla devam.
    }
  }

  /// Seçimi hem bellekte hem diske yazar. Bellek önce güncelleniyor ki
  /// arayüz diski beklemeden değişsin.
  static Future<void> temaYaz(TemaTercihi t) async {
    tema.value = t;
    try {
      final f = await _dosya();
      await f.writeAsString(jsonEncode({'schema': 1, 'tema': t.name}));
    } catch (_) {
      // Yazılamadıysa seçim bu oturum boyunca geçerli kalır.
    }
  }
}
