import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'ayarlar.dart';
import 'day_record.dart';

/// Diske yazılan gün önbelleği.
///
/// Sorun: her açılışta 90 günün tamamı Health Connect'ten okunuyordu. Ham
/// nabız tek başına yüz binlerce kayıt; parça parça okunup dakikalık
/// kovalara indirgense bile dakikalar sürüyor ve bunların neredeyse hepsi
/// boşa gidiyor, çünkü 60 gün önceki bir gece bir daha değişmiyor.
///
/// Çözüm: okunan günler diske yazılıyor. Açılışta önce bu dosya okunuyor
/// (ekran anında geliyor), sonra arka planda yalnızca **son birkaç gün**
/// Health Connect'ten tazeleniyor. Taban çizgiler ve bütün türetilmiş
/// ölçüler zaten bellekte, tam listeden yeniden hesaplanıyor.
///
/// Neyin güvenli olduğu: geçmiş günler. Neyin olmadığı: bugün ve dün
/// (bileklik geç eşitleyebilir), bir de kullanıcının kendi ayarları
/// (yaş nabız bölgelerini belirliyor). İkincisi için parmak izi var:
/// hesabı etkileyen bir şey değişirse önbellek baştan reddediliyor.
class Onbellek {
  static const String dosyaAdi = 'kerteriz_onbellek.json';
  static const int sema = 1;

  /// Kaç günün gece nabız serisi saklansın. Seri gün başına ~700 örnek;
  /// 90 gün için megabaytlara çıkıyor ve yalnızca kardiyak toparlanma ile
  /// türetilmiş dinlenme nabzı için okunuyor. İkisi de kaydın içinde zaten
  /// hesaplanmış duruyor.
  static const int geceNabziGunu = 7;

  /// Önbellek bu kadar gün sonra tam okumaya zorlanır. Sebebi kapsama
  /// sayıları: tazeleme yalnızca son günleri okuduğu için Veri sekmesindeki
  /// "hangi tipten kaç kayıt geldi" tablosu zamanla bayatlar.
  static const int tamOkumaAraligiGun = 14;

  /// Hesabı etkileyen her şey burada. Değişirse önbellek atılır.
  static String get parmakIzi {
    final atlanan = Config.atlananTipler.toList()..sort();
    return [
      sema,
      Config.version,
      Config.historyDays,
      Config.baselineWindow,
      Config.sleepNeedBaseMinutes,
      Ayarlar.yas, // nabız bölgeleri buna bağlı
      atlanan.join('+'),
    ].join('|');
  }

  static Future<File> _dosya() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
  }

  /// Geçerli bir önbellek varsa döndürür, yoksa null. Bozuk dosya, eski
  /// parmak izi ve okunamayan dosya aynı şey sayılır: null.
  static Future<OnbellekIcerik?> oku() async {
    try {
      final f = await _dosya();
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map) return null;
      if (m['parmakIzi'] != parmakIzi) return null;

      final liste = m['gunler'];
      if (liste is! List || liste.isEmpty) return null;

      final gunler = liste
          .map((e) => DayRecord.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final sayilar = <String, int>{};
      final s = m['sayilar'];
      if (s is Map) {
        s.forEach((k, v) {
          if (v is num) sayilar['$k'] = v.toInt();
        });
      }

      DateTime? tarih(String k) {
        final v = m[k];
        return v is String ? DateTime.tryParse(v) : null;
      }

      return OnbellekIcerik(
        gunler: gunler,
        sayilar: sayilar,
        ilkKayit: tarih('ilkKayit'),
        sonKayit: tarih('sonKayit'),
        tamOkuma: tarih('tamOkuma') ?? DateTime.fromMillisecondsSinceEpoch(0),
        istenenGun: (m['istenenGun'] as num?)?.toInt() ?? Config.historyDays,
      );
    } catch (_) {
      return null;
    }
  }

  /// Yazma başarısız olursa yutulur: önbellek bir hızlandırma, veri kaynağı
  /// değil. Yazılamazsa bir sonraki açılış yavaş olur, o kadar.
  static Future<void> yaz(OnbellekIcerik i) async {
    try {
      final f = await _dosya();
      final esik = DateTime.now().subtract(
        const Duration(days: geceNabziGunu),
      );
      await f.writeAsString(jsonEncode({
        'parmakIzi': parmakIzi,
        'yazilmaMs': DateTime.now().millisecondsSinceEpoch,
        'tamOkuma': i.tamOkuma.toIso8601String(),
        'istenenGun': i.istenenGun,
        'ilkKayit': i.ilkKayit?.toIso8601String(),
        'sonKayit': i.sonKayit?.toIso8601String(),
        'sayilar': i.sayilar,
        'gunler': i.gunler
            .map((d) => d.toJson(geceNabzi: !d.date.isBefore(esik)))
            .toList(),
      }));
    } catch (_) {}
  }

  static Future<void> sil() async {
    try {
      final f = await _dosya();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Önbelleğin içeriği. Günlerin yanında Veri sekmesinin gösterdiği kapsama
/// bilgisi de taşınıyor: tazeleme yalnızca son günleri okuduğu için o
/// sayılar son **tam** okumadan geliyor ve tarihiyle birlikte gösteriliyor.
class OnbellekIcerik {
  final List<DayRecord> gunler;
  final Map<String, int> sayilar;
  final DateTime? ilkKayit;
  final DateTime? sonKayit;
  final DateTime tamOkuma;
  final int istenenGun;

  const OnbellekIcerik({
    required this.gunler,
    required this.sayilar,
    required this.tamOkuma,
    required this.istenenGun,
    this.ilkKayit,
    this.sonKayit,
  });

  /// Önbellekteki en son günden bugüne kaç gün geçti. Tazeleme penceresi
  /// bundan çıkıyor: uygulamayı on gün açmadıysan on günü okumak gerekiyor.
  int get bosluk {
    if (gunler.isEmpty) return Config.historyDays;
    final bugun = DateTime.now();
    final son = gunler.last.date;
    return DateTime(bugun.year, bugun.month, bugun.day)
        .difference(DateTime(son.year, son.month, son.day))
        .inDays;
  }

  /// Kapsama tablosu bayatladıysa tam okuma gerekiyor.
  bool get tamOkumaGerek =>
      DateTime.now().difference(tamOkuma).inDays >= Onbellek.tamOkumaAraligiGun;
}
