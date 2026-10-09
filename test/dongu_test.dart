import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/metrics/dongu.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/metrics/insights.dart';

import 'helpers.dart';

/// 90 gün, 28 günlük döngüler; her döngünün ilk 4 günü regl. Luteal evrede
/// (döngünün 15-28. günleri) nabız [lutealNabiz] kadar yüksek.
List<DayRecord> donguluGunler({double lutealNabiz = 4, double lutealHrv = 0.85}) {
  return gunler(90, f: (date, i) {
    final dg = i % 28 + 1;
    final luteal = dg > 14;
    final g = gun(date,
        rhr: 56 + (i % 3) * 0.5 + (luteal ? lutealNabiz : 0),
        hrv: (50 + (i % 3) * 1.0) * (luteal ? lutealHrv : 1));
    g.regl = dg <= 4;
    return g;
  });
}

void main() {
  group('döngü', () {
    test('başlangıçlar ve uzunluk', () {
      final days = donguluGunler();
      final bas = Dongu.baslangiclar(days);
      expect(bas.length, 4); // 0, 28, 56, 84. günler
      expect(Dongu.uzunluk(bas), 28);
    });

    test('döngü günü ve evre', () {
      final days = donguluGunler();
      Dongu.isaretle(days);
      expect(days[0].donguGunu, 1);
      expect(days[0].donguEvresi, 'regl');
      expect(days[8].donguEvresi, 'folikuler');
      expect(days[20].donguGunu, 21);
      expect(days[20].donguEvresi, 'luteal');
    });

    test('regl kaydı yoksa döngü bilinmiyor', () {
      final days = gunler(30);
      Dongu.isaretle(days);
      expect(days.every((d) => d.donguGunu == null), isTrue);
      expect(Dongu.farklar(days), isNull);
    });

    test('fark kişinin kendi verisinden', () {
      final days = donguluGunler(lutealNabiz: 4, lutealHrv: 0.85);
      Dongu.isaretle(days);
      final f = Dongu.farklar(days)!;
      expect(f.rhr, closeTo(4, 0.3));
      expect(f.hrvYuzde, closeTo(-15, 1.5));
    });

    test('düzeltme luteal evrede hazırlığı düşürmüyor', () {
      final duzeltmeli = donguluGunler();
      MetricsEngine.run(duzeltmeli);
      // Aynı veri, regl kaydı olmadan: düzeltme yok.
      final duz = donguluGunler()..forEach((d) => d.regl = false);
      MetricsEngine.run(duz);
      // Luteal evrenin ortası (döngünün 20. günü, üçüncü döngü).
      const i = 56 + 19;
      expect(duzeltmeli[i].donguDuzeltildi, isTrue);
      expect(duz[i].donguDuzeltildi, isFalse);
      expect(duzeltmeli[i].readiness, greaterThan(duz[i].readiness));
    });
  });

  group('HRV yoksa', () {
    List<HrSample> seri(double bas, double dip) => [
          for (var k = 0; k < 40; k++)
            HrSample(k * 10, k < 3 ? bas : (k < 20 ? dip + (k % 2) : bas - 4))
        ];

    test('gece kardiyak toparlanması hazırlığa katılır', () {
      final days = gunler(20, f: (date, i) => gun(date,
          hrv: null, timeInBed: 400, nightHr: seri(62, 50 + (i % 3).toDouble())));
      MetricsEngine.run(days);
      expect(days.last.kardiyakYedek, isTrue);
      expect(days[3].kardiyakYedek, isFalse); // taban çizgi daha kurulmadı
    });

    test('HRV varsa yedek kullanılmaz', () {
      final days = gunler(20, f: (date, i) => gun(date,
          timeInBed: 400, nightHr: seri(62, 50 + (i % 3).toDouble())));
      MetricsEngine.run(days);
      expect(days.last.kardiyakYedek, isFalse);
    });
  });

  group('beslenme karşılaştırmaları', () {
    test('geç yemek: son öğün yatışa yakın olan gecelerin uyku skoru', () {
      final days = gunler(20, f: (date, i) => gun(date, bedHour: 23));
      MetricsEngine.run(days);
      for (var i = 0; i < 19; i++) {
        final gec = i.isEven;
        days[i].sonOgun =
            DateTime(days[i].date.year, days[i].date.month, days[i].date.day, gec ? 22 : 18);
        days[i].kcalAlinan = 2000;
        days[i + 1].sleepScore = gec ? 60 : 85;
      }
      final c = Deneyler.beslenme(days).firstWhere((c) => c.key == 'gecYemek');
      expect(c.a, 60);
      expect(c.b, 85);
    });

    test('öğleden sonra kafein', () {
      final days = gunler(20);
      MetricsEngine.run(days);
      for (var i = 0; i < 19; i++) {
        final ogleden = i % 3 == 0;
        days[i].sonKafein = DateTime(
            days[i].date.year, days[i].date.month, days[i].date.day, ogleden ? 17 : 9);
        days[i + 1].sleepScore = ogleden ? 70 : 80;
      }
      final c = Deneyler.beslenme(days).firstWhere((c) => c.key == 'kafein');
      expect(c.a, 70);
      expect(c.b, 80);
    });

    test('beslenme verisi yoksa karşılaştırma yok', () {
      final days = gunler(20);
      MetricsEngine.run(days);
      expect(Deneyler.beslenme(days), isEmpty);
    });
  });
}
