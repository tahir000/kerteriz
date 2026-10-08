import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/metrics/gun_ici.dart';
import 'package:kerteriz/metrics/insights.dart';

import 'helpers.dart';

/// Gün içi dilimleri olan bir gün: 07:00'de uyanış, gündüz sakin nabız
/// [sakin], [ozel] ile bazı dilimler değiştirilebilir.
DayRecord gunIciGun(DateTime date,
    {double sakin = 70, Map<int, double>? nabiz, Map<int, int>? adim}) {
  final d = gun(date, bedHour: 23, timeInBed: 480); // 23:00 -> 07:00
  d.gunNabzi = [
    for (var b = 0; b < DayRecord.dilimSayisi; b++) nabiz?[b] ?? sakin
  ];
  d.gunAdim = [for (var b = 0; b < DayRecord.dilimSayisi; b++) adim?[b] ?? 0];
  return d;
}

void main() {
  const hrMax = 190.0;

  group('sakin nabız', () {
    test('az veriyle dinlenme nabzı + 10', () {
      final d = gun(DateTime(2026, 10, 7), rhr: 60);
      expect(GunIci.sakinNabiz([d]), 70);
    });

    test('hareketsiz uyanık dilimlerin alt çeyreği; uyku ve hareket sayılmaz', () {
      final days = gunler(3, f: (date, _) => gunIciGun(date, sakin: 72, nabiz: {
            for (var b = 0; b < 28; b++) b: 50, // uyku (07:00'den önce): düşük, sayılmamalı
            60: 130, // yürüyüş, adımlı
          }, adim: {60: 900}));
      expect(GunIci.sakinNabiz(days), 72);
    });
  });

  group('stres', () {
    final d = gunIciGun(DateTime(2026, 10, 7),
        nabiz: {40: 100, 41: 70, 50: 140}, adim: {50: 1200});

    test('hareketsizken yükselen nabız stres', () {
      final s = GunIci.stres(d, 70, hrMax);
      // (100 - 70) / (0.25 * 120) = 1.0
      expect(s[40], closeTo(1, 1e-9));
      expect(s[41], 0);
    });

    test('hareketli dilim, uyku ve antrenman sayılmaz', () {
      d.antrenmanlar = [
        Antrenman('RUNNING', DateTime(2026, 10, 7, 18), DateTime(2026, 10, 7, 19))
      ];
      final s = GunIci.stres(d, 70, hrMax);
      expect(s[50], isNull); // adımlı
      expect(s[10], isNull); // 02:30, uykuda
      expect(s[72], isNull); // 18:00, antrenmanda
      expect(s[71], isNotNull);
      d.antrenmanlar = [];
    });
  });

  group('enerji', () {
    test('hazırlıkla başlar, uyanık saatlerle azalır', () {
      final days = gunler(10, f: (date, _) => gunIciGun(date));
      MetricsEngine.run(days);
      final d = days.last;
      final e = GunIci.enerji(d, sakin: 70, hrMax: hrMax, sonDilim: 28 + 8)!;
      expect(e.ilkDilim, 28); // 07:00
      expect(e.baslangic, d.readiness);
      // 9 dilim = 2 saat 15 dk uyanık, stres ve yük yok.
      expect(e.simdi, closeTo(d.readiness - 1.5 * 9 * 15 / 60, 1e-6));
      expect(e.stresKaybi, 0);
    });

    test('stres ve yük enerjiyi daha çok düşürür', () {
      final sakinGun = gunIciGun(DateTime(2026, 10, 7));
      final yogunGun = gunIciGun(DateTime(2026, 10, 7),
          nabiz: {for (var b = 30; b < 40; b++) b: 100, 45: 160});
      for (final d in [sakinGun, yogunGun]) {
        d.readiness = 80;
      }
      // Taban çizgi kurulmamışsa uyku skoru kullanılır; burada hazırlık
      // kullanılsın diye taban çizgiyi elle doldur.
      sakinGun.hrvBaselineN = yogunGun.hrvBaselineN = 14;
      final a = GunIci.enerji(sakinGun, sakin: 70, hrMax: hrMax, sonDilim: 60)!;
      final b = GunIci.enerji(yogunGun, sakin: 70, hrMax: hrMax, sonDilim: 60)!;
      expect(b.simdi, lessThan(a.simdi));
      expect(b.stresKaybi, greaterThan(0));
      expect(b.yukKaybi, greaterThan(a.yukKaybi));
    });

    test('dilim yoksa null', () {
      expect(
          GunIci.enerji(gun(DateTime(2026, 10, 7)),
              sakin: 70, hrMax: hrMax, sonDilim: 50),
          isNull);
    });
  });

  test('özet: son veri dilimi ve yüksek stres süresi', () {
    final d = gunIciGun(DateTime(2026, 10, 7),
        nabiz: {for (var b = 40; b < 44; b++) b: 105});
    for (var b = 50; b < DayRecord.dilimSayisi; b++) {
      d.gunNabzi[b] = null; // 12:30'dan sonra veri yok
    }
    final o = GunIci.ozet([d], d,
        hrMax: hrMax, simdi: DateTime(2026, 10, 7, 15))!;
    expect(o.sonVeriDilimi, 49);
    expect(o.yuksekStresDk, 60);
    expect(GunIci.dilimSaati(49), '12:15');
  });

  test('antrenman yükü günlükle aynı ölçek', () {
    final a = Antrenman('RUNNING', DateTime(2026, 10, 7, 18), DateTime(2026, 10, 7, 19));
    a.yukHam = 0;
    expect(a.yuk, 0);
    a.yukHam = 24 * (2.718281828 - 1); // ln(1 + x/24) = 1
    expect(a.yuk, closeTo(6.9, 1e-3));
    a.yukHam = 100000;
    expect(a.yuk, 21);
    expect(a.dakika, 60);
    final geri = Antrenman.fromJson(a.toJson());
    expect(geri.tur, 'RUNNING');
    expect(geri.yukHam, a.yukHam);
  });

  test('his ve skor karşılaştırması', () {
    final days = gunler(20);
    MetricsEngine.run(days);
    final his = <String, int>{};
    for (var i = 8; i < 20; i++) {
      days[i].readiness = i.isEven ? 80 : 40;
      his[gunAnahtari(days[i].date)] = i.isEven ? 5 : 1;
    }
    final c = Deneyler.hisVeSkor(days, his)!;
    expect(c.a, 80);
    expect(c.b, 40);
    expect(c.nA + c.nB, 12);
    // "Normal" (3) sayılmaz.
    his.updateAll((k, v) => 3);
    expect(Deneyler.hisVeSkor(days, his), isNull);
  });
}
