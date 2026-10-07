import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Açılış izi: uygulamanın hangi adıma kadar geldiğini diske yazar.
///
/// Neden dosyaya: işletim sistemi uygulamayı öldürdüğünde (Health Connect
/// eklentisi arka planda çökerse ya da MagicOS süreci kapatırsa) Dart
/// tarafındaki hiçbir `catch` çalışmaz, ekranda hata görünmez. Diske yazılan
/// iz ise kalır; bir sonraki açılışta okunup gösterilebilir.
///
/// İki dosya var: [_aktif] o anki çalışmanın izi, [_onceki] bir öncekinin.
/// Açılışta aktif dosya "bitti" ile kapanmamışsa çökme sayılır ve önceki
/// olarak saklanır.
class Tani {
  static const String _aktif = 'kerteriz_iz.log';
  static const String _onceki = 'kerteriz_iz_onceki.log';
  static const String bittiIsareti = 'BITTI';

  static Directory? _dir;
  static bool _hazir = false;

  /// İz kapandı mı. [bitti] çağrıldıktan sonra hiçbir şey yazılmıyor.
  ///
  /// Bu bayrak olmadan şöyle oluyordu: uygulama önbellekten açılıyor, iz
  /// `BITTI` ile kapanıyor, sonra arka plandaki tazeleme ize yazmaya devam
  /// ediyor ve dosyanın son satırı artık `BITTI` olmuyor. Bir sonraki
  /// açılış bunu çökme sanıp güvenli moda düşüyordu; güvenli mod oturumunda
  /// da `BITTI` yazılmadığı için uygulama bir daha normal açılmıyordu.
  static bool _kapandi = false;

  /// Bir önceki çalışma yarıda kaldıysa onun izi; kalmadıysa null.
  static String? cokmeIzi;

  static Future<Directory> _klasor() async =>
      _dir ??= await getApplicationSupportDirectory();

  static File _dosya(Directory d, String ad) =>
      File('${d.path}${Platform.pathSeparator}$ad');

  /// Uygulama açılırken bir kez çağrılır. Önceki izi devralır ve yenisini açar.
  static Future<void> baslat() async {
    try {
      final d = await _klasor();
      final a = _dosya(d, _aktif);
      if (await a.exists()) {
        final metin = await a.readAsString();
        if (!metin.trimRight().endsWith(bittiIsareti)) {
          cokmeIzi = metin;
          await _dosya(d, _onceki).writeAsString(metin);
        }
      }
      await a.writeAsString('');
      _kapandi = false;
      _hazir = true;
    } catch (_) {
      _hazir = false;
    }
  }

  /// Bir adımı ize yazar. Hata verirse yutulur: tanılama hiçbir zaman
  /// uygulamanın önüne geçmemeli.
  static Future<void> iz(String adim) async {
    if (!_hazir || _kapandi) return;
    try {
      final d = await _klasor();
      final zaman = DateTime.now().toIso8601String().substring(11, 23);
      await _dosya(d, _aktif)
          .writeAsString('$zaman  $adim\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Açılış başarıyla bittiğinde çağrılır; bundan sonra çökme sayılmaz ve
  /// ize başka hiçbir şey yazılmaz.
  static Future<void> bitti() async {
    await iz(bittiIsareti);
    _kapandi = true;
  }

  /// Çökme izini temizler (kullanıcı "anladım" dedikten sonra).
  static Future<void> temizle() async {
    cokmeIzi = null;
    try {
      final d = await _klasor();
      final o = _dosya(d, _onceki);
      if (await o.exists()) await o.delete();
    } catch (_) {}
  }
}
