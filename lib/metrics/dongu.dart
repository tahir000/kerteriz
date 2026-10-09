import 'dart:math' as math;

import '../data/day_record.dart';
import 'engine.dart';

/// Regl döngüsü: döngü günü, evre ve hazırlık düzeltmesi.
///
/// Döngünün ikinci yarısında (luteal evre) dinlenme nabzı yükselir, HRV
/// düşer. Bunu bilmeyen bir hazırlık skoru her ay birkaç gün "dinlen" der,
/// oysa vücut beklenen şeyi yapıyor.
///
/// Düzeltmenin büyüklüğü **sabit bir katsayı değil**: kişinin kendi geçmiş
/// döngülerinde luteal günlerin foliküler günlere göre ortalama farkı. Yeterli
/// geçmiş yoksa (en az iki döngü başlangıcı ve her evrede sekiz gün) düzeltme
/// yapılmıyor; yalnızca evre gösteriliyor.
///
/// Evre tahmini kaba: yumurtlama döngü sonundan ~14 gün önce varsayılıyor.
/// Kerteriz bir döngü takip uygulaması değil, doğurganlık tahmini vermiyor.
class Dongu {
  /// Regl kaydının ilk günleri bu kadar gün "regl" evresi sayılır.
  static const int reglGun = 5;

  /// Luteal evre uzunluğu (gün). Kişiden kişiye az değişir; foliküler evre
  /// değişkendir.
  static const int lutealGun = 14;

  /// Döngü uzunluğu bu aralık dışındaysa ölçüm hatası sayılır.
  static const int enKisaDongu = 21, enUzunDongu = 40;
  static const int varsayilanDongu = 28;

  /// Düzeltme için her evrede en az bu kadar gün.
  static const int enAzGun = 8;

  static int _gunFarki(DateTime a, DateTime b) =>
      (a.difference(b).inHours / 24).round();

  /// Döngü başlangıç günleri: işaretli başlangıç ya da en az 5 gün regl'siz
  /// geçtikten sonraki ilk regl günü. Liste tarihe göre sıralı olmalı.
  static List<DateTime> baslangiclar(List<DayRecord> days) {
    final sonuc = <DateTime>[];
    DateTime? sonRegl;
    for (final d in days) {
      if (!d.regl && !d.donguBaslangici) continue;
      final yeni = d.donguBaslangici ||
          sonRegl == null ||
          _gunFarki(d.date, sonRegl) > 5;
      if (yeni && (sonuc.isEmpty || _gunFarki(d.date, sonuc.last) >= 15)) {
        sonuc.add(d.date);
      }
      if (d.regl) sonRegl = d.date;
    }
    return sonuc;
  }

  /// Kişinin tipik döngü uzunluğu: ardışık başlangıçlar arasının medyanı.
  static int uzunluk(List<DateTime> bas) {
    final farklar = <double>[];
    for (var i = 1; i < bas.length; i++) {
      final f = _gunFarki(bas[i], bas[i - 1]);
      if (f >= enKisaDongu && f <= enUzunDongu) farklar.add(f.toDouble());
    }
    return farklar.isEmpty
        ? varsayilanDongu
        : MetricsEngine.median(farklar).round();
  }

  /// Her güne döngü günü ve evre yazar. Son başlangıçtan sonra
  /// [enUzunDongu] günden fazla geçmişse döngü bilinmiyor sayılır.
  static void isaretle(List<DayRecord> days) {
    for (final d in days) {
      d.donguGunu = null;
      d.donguEvresi = null;
    }
    final bas = baslangiclar(days);
    if (bas.isEmpty) return;
    final uzun = uzunluk(bas);
    var k = 0;
    for (final d in days) {
      while (k + 1 < bas.length && !d.date.isBefore(bas[k + 1])) {
        k++;
      }
      if (d.date.isBefore(bas[k])) continue;
      final gun = _gunFarki(d.date, bas[k]) + 1;
      if (gun > enUzunDongu) continue;
      d.donguGunu = gun;
      d.donguEvresi = (gun <= reglGun || d.regl)
          ? 'regl'
          : (gun > uzun - lutealGun ? 'luteal' : 'folikuler');
    }
  }

  /// Düzeltme için ne kadar veri birikti: döngü başlangıcı ve her evrede
  /// dinlenme nabzı olan gün sayısı. Ekran "2/2, 5/8, 8/8" gibi gösteriyor.
  static ({int baslangic, int luteal, int folikuler}) ilerleme(
      List<DayRecord> days) {
    var l = 0, f = 0;
    for (final d in days) {
      if (d.rhr == null) continue;
      if (d.donguEvresi == 'luteal') l++;
      if (d.donguEvresi == 'folikuler') f++;
    }
    return (baslangic: baslangiclar(days).length, luteal: l, folikuler: f);
  }

  /// Luteal günlerin foliküler günlere göre ortalama farkı (kişinin kendi
  /// verisinden). Yeterli veri yoksa null.
  static DonguFarki? farklar(List<DayRecord> days) {
    if (baslangiclar(days).length < 2) return null;
    final lRhr = <double>[], fRhr = <double>[];
    final lHrv = <double>[], fHrv = <double>[];
    for (final d in days) {
      final e = d.donguEvresi;
      if (e != 'luteal' && e != 'folikuler') continue;
      if (d.rhr != null) (e == 'luteal' ? lRhr : fRhr).add(d.rhr!);
      if (d.hrv != null && d.hrv! > 0) {
        (e == 'luteal' ? lHrv : fHrv).add(math.log(d.hrv!));
      }
    }
    double? fark(List<double> l, List<double> f) =>
        (l.length >= enAzGun && f.length >= enAzGun)
            ? MetricsEngine.mean(l) - MetricsEngine.mean(f)
            : null;
    final r = fark(lRhr, fRhr), h = fark(lHrv, fHrv);
    if (r == null && h == null) return null;
    return DonguFarki(rhr: r ?? 0, lnHrv: h ?? 0);
  }
}

class DonguFarki {
  /// Luteal - foliküler, atım/dk (genelde pozitif).
  final double rhr;

  /// Luteal - foliküler, ln(HRV) (genelde negatif).
  final double lnHrv;

  const DonguFarki({required this.rhr, required this.lnHrv});

  /// HRV farkının yüzde karşılığı: exp(lnHrv) - 1.
  double get hrvYuzde => (math.exp(lnHrv) - 1) * 100;
}
