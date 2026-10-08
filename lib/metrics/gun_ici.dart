import 'dart:math' as math;

import '../config.dart';
import '../data/day_record.dart';
import 'engine.dart';

/// Gün içi stres ve enerji.
///
/// İkisi de 15 dakikalık dilimlerle ([DayRecord.gunNabzi], [DayRecord.gunAdim])
/// hesaplanıyor. Hazırlık skoru günde bir kez, sabah veriliyor; bunlar gün
/// boyunca ne olduğunu gösteriyor.
///
/// **Stres:** hareket etmezken nabzın yükselmesi. Yürürken ya da antrenmanda
/// yükselen nabız stres değil, o dilimler sayılmıyor. Referans dinlenme nabzı
/// değil, kişinin **kendi sakin uyanık nabzı**: uyanıkken oturan birinin
/// nabzı uykudakinden zaten 10-15 atım yüksek. Bu referans son günlerin
/// hareketsiz uyanık dilimlerinin alt çeyreğinden çıkıyor.
///
/// **Enerji:** sabah hazırlıkla başlıyor; gün içinde yük, stres ve uyanık
/// geçen saatle azalıyor. Bu bir tahmin, ölçüm değil: katsayılar sabit ve
/// arayüz bunu açıkça yazıyor. Amaç "öğleden sonra neden bittim" sorusuna
/// kaba ama tutarlı bir cevap.
class GunIci {
  /// Bir dilimde bundan fazla adım varsa hareket sayılır, stres hesaplanmaz.
  /// 15 dakikada 150 adım: dakikada 10, yani ev içinde dolaşmak bile değil.
  static const int hareketEsigi = 150;

  /// Stres ölçeği: sakin nabzın üstünde, nabız rezervinin bu kadarı 1.0 stres.
  static const double stresOlcegi = 0.25;

  /// Sakin nabız referansı kurulamazsa: dinlenme nabzı + bu kadar.
  static const double yedekFark = 10;

  // ---- enerji katsayıları (tahmin; arayüzde yazıyor) ----

  /// Yükün ham birimi (bölge ağırlıklı dakika) başına enerji kaybı.
  /// 21 yüklü (en ağır) bir gün ~480 ham birim; o gün ~60 puan götürür.
  static const double yukKaybi = 0.125;

  /// Tam stresli bir saat (stres 1.0) bu kadar puan götürür.
  static const double stresKaybi = 6;

  /// Uyanık geçen her saat bu kadar puan götürür.
  static const double uyaniklikKaybi = 1.5;

  /// Bir dilimin uyku içinde olup olmadığı (o günün kaydının gece uykusu
  /// sabah bitiyor; akşamki uyku ertesi günün kaydında).
  static bool _uykuda(DayRecord d, int b) {
    if (d.wakeEnd == null) return false;
    final bas = d.date.add(Duration(minutes: b * DayRecord.dilimDk));
    return bas.isBefore(d.wakeEnd!);
  }

  static bool _antrenmanda(DayRecord d, int b) {
    final bas = d.date.add(Duration(minutes: b * DayRecord.dilimDk));
    final bit = bas.add(const Duration(minutes: DayRecord.dilimDk));
    return d.antrenmanlar.any((a) => a.bas.isBefore(bit) && a.bit.isAfter(bas));
  }

  /// Dilim hareketsiz ve uyanık mı (stres hesaplanabilir mi). [yatis]
  /// verilirse o akşamki yatıştan sonrası da uyku sayılır (ertesi günün
  /// kaydındaki uyku).
  static bool sakinDilim(DayRecord d, int b, {DateTime? yatis}) =>
      d.gunNabzi.length == DayRecord.dilimSayisi &&
      d.gunNabzi[b] != null &&
      (d.gunAdim.length == DayRecord.dilimSayisi ? d.gunAdim[b] : 0) <= hareketEsigi &&
      !_uykuda(d, b) &&
      !(yatis != null &&
          !d.date.add(Duration(minutes: b * DayRecord.dilimDk)).isBefore(yatis)) &&
      !_antrenmanda(d, b);

  /// Kişinin sakin uyanık nabzı: son [gun] günün hareketsiz uyanık
  /// dilimlerinin alt çeyreği. En az 20 dilim yoksa dinlenme nabzına düşer.
  static double sakinNabiz(List<DayRecord> days, {int gun = 7}) {
    final degerler = <double>[];
    final bas = math.max(0, days.length - gun);
    for (var i = bas; i < days.length; i++) {
      final d = days[i];
      final yatis = i + 1 < days.length ? days[i + 1].bedStart : null;
      for (var b = 0; b < DayRecord.dilimSayisi; b++) {
        if (sakinDilim(d, b, yatis: yatis)) degerler.add(d.gunNabzi[b]!);
      }
    }
    if (degerler.length < 20) {
      final rhr = days.isEmpty ? null : days.last.rhr;
      return (rhr ?? 60) + yedekFark;
    }
    degerler.sort();
    return degerler[(degerler.length * 0.25).floor()];
  }

  /// Dilim başına stres (0..1); hesaplanamayan dilim null.
  static List<double?> stres(DayRecord d, double sakin, double hrMax) {
    if (d.gunNabzi.length != DayRecord.dilimSayisi) {
      return List<double?>.filled(DayRecord.dilimSayisi, null);
    }
    final olcek = stresOlcegi * math.max(20, hrMax - sakin);
    return [
      for (var b = 0; b < DayRecord.dilimSayisi; b++)
        sakinDilim(d, b)
            ? MetricsEngine.clamp((d.gunNabzi[b]! - sakin) / olcek, 0, 1)
            : null,
    ];
  }

  /// Dilimin ham yükü: bölge ağırlıklı dakikalar + adım katkısı (günlük
  /// yükle aynı formül, dilime indirgenmiş).
  static double dilimYuku(DayRecord d, int b, double hrMax) {
    if (d.gunNabzi.length != DayRecord.dilimSayisi) return 0;
    final v = d.gunNabzi[b];
    final adim = d.gunAdim.length == DayRecord.dilimSayisi ? d.gunAdim[b] : 0;
    var ham = adim * 0.0022;
    if (v != null) {
      final rest = d.rhr ?? 60;
      final aralik = hrMax - rest;
      final hrr = aralik <= 0 ? 0.0 : (v - rest) / aralik;
      final z = hrr >= 0.85
          ? 4
          : hrr >= 0.70
              ? 3
              : hrr >= 0.60
                  ? 2
                  : hrr >= 0.50
                      ? 1
                      : 0;
      ham += Config.bolgeAgirliklari[z] * DayRecord.dilimDk;
    }
    return ham;
  }

  /// Uyanılan dilimden [sonDilim]'e kadar enerji eğrisi. Başlangıç sabahki
  /// hazırlık; taban çizgi kurulmadıysa uyku skoru.
  static EnerjiEgrisi? enerji(
    DayRecord d, {
    required double sakin,
    required double hrMax,
    required int sonDilim,
  }) {
    if (d.gunNabzi.length != DayRecord.dilimSayisi) return null;
    final ilk = d.wakeEnd == null
        ? 0
        : (d.wakeEnd!.difference(d.date).inMinutes / DayRecord.dilimDk)
            .ceil()
            .clamp(0, DayRecord.dilimSayisi - 1);
    final son = sonDilim.clamp(0, DayRecord.dilimSayisi - 1);
    if (son < ilk) return null;

    final bas = (d.baselineNights >= Config.minBaselineNights
            ? d.readiness
            : d.sleepScore)
        .toDouble();
    if (bas <= 0) return null;

    final s = stres(d, sakin, hrMax);
    var e = bas;
    final egri = <double>[];
    var yukKayip = 0.0, stresKayip = 0.0, uyanikKayip = 0.0;
    for (var b = ilk; b <= son; b++) {
      final y = dilimYuku(d, b, hrMax) * yukKaybi;
      final st = (s[b] ?? 0) * stresKaybi * DayRecord.dilimDk / 60;
      final u = uyaniklikKaybi * DayRecord.dilimDk / 60;
      yukKayip += y;
      stresKayip += st;
      uyanikKayip += u;
      e = MetricsEngine.clamp(e - y - st - u, 0, 100);
      egri.add(e);
    }
    return EnerjiEgrisi(
      baslangic: bas,
      ilkDilim: ilk,
      degerler: egri,
      yukKaybi: yukKayip,
      stresKaybi: stresKayip,
      uyaniklikKaybi: uyanikKayip,
    );
  }

  /// Bugünün özeti. [simdi] bugünün kaydının gününde olmalı.
  static GunIciOzet? ozet(List<DayRecord> days, DayRecord bugun,
      {required double hrMax, DateTime? simdi}) {
    if (bugun.gunNabzi.length != DayRecord.dilimSayisi) return null;
    final n = simdi ?? DateTime.now();
    final sonDilim = n.difference(bugun.date).inMinutes ~/ DayRecord.dilimDk;
    final sakin = sakinNabiz(days);
    final s = stres(bugun, sakin, hrMax);

    // Son veri olan dilim: bileklik geç eşitleyebilir, "şimdi" olmayabilir.
    var sonVeri = -1;
    for (var b = math.min(sonDilim, DayRecord.dilimSayisi - 1); b >= 0; b--) {
      if (bugun.gunNabzi[b] != null) {
        sonVeri = b;
        break;
      }
    }
    if (sonVeri < 0) return null;

    var yuksekDk = 0, olculen = 0;
    var toplam = 0.0;
    for (var b = 0; b <= sonVeri; b++) {
      final v = s[b];
      if (v == null) continue;
      olculen++;
      toplam += v;
      if (v >= 0.5) yuksekDk += DayRecord.dilimDk;
    }
    // Şimdiki stres: son bir saatin ölçülebilen dilimleri.
    final sonSaat = [
      for (var b = math.max(0, sonVeri - 3); b <= sonVeri; b++)
        if (s[b] != null) s[b]!
    ];
    return GunIciOzet(
      stres: s,
      sakinNabiz: sakin,
      ortalamaStres: olculen == 0 ? null : toplam / olculen,
      simdikiStres: sonSaat.isEmpty ? null : MetricsEngine.mean(sonSaat),
      yuksekStresDk: yuksekDk,
      sonVeriDilimi: sonVeri,
      enerji: enerji(bugun, sakin: sakin, hrMax: hrMax, sonDilim: sonVeri),
    );
  }

  /// Dilim numarasını saate çevirir: 34 -> 08:30.
  static String dilimSaati(int b) {
    final m = b * DayRecord.dilimDk;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}

class EnerjiEgrisi {
  final double baslangic;
  final int ilkDilim;
  final List<double> degerler;
  final double yukKaybi, stresKaybi, uyaniklikKaybi;

  const EnerjiEgrisi({
    required this.baslangic,
    required this.ilkDilim,
    required this.degerler,
    required this.yukKaybi,
    required this.stresKaybi,
    required this.uyaniklikKaybi,
  });

  double get simdi => degerler.isEmpty ? baslangic : degerler.last;
}

class GunIciOzet {
  final List<double?> stres;
  final double sakinNabiz;
  final double? ortalamaStres;
  final double? simdikiStres;
  final int yuksekStresDk;
  final int sonVeriDilimi;
  final EnerjiEgrisi? enerji;

  const GunIciOzet({
    required this.stres,
    required this.sakinNabiz,
    required this.ortalamaStres,
    required this.simdikiStres,
    required this.yuksekStresDk,
    required this.sonVeriDilimi,
    required this.enerji,
  });
}
