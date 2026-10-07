import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/config.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/data/etiketler.dart';
import 'package:kerteriz/data/hatirlatici.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/metrics/insights.dart';

import 'helpers.dart';

void main() {
  group('haftalık özet', () {
    test('4 geceden azsa null', () {
      final days = gunler(7, f: (date, i) => gun(date, asleep: i < 4 ? 0 : 480));
      MetricsEngine.run(days);
      expect(Insights.weekly(days), isNull);
    });

    test('tek hafta varsa önceki hafta boş', () {
      final days = gunler(7);
      MetricsEngine.run(days);
      final w = Insights.weekly(days)!;
      expect(w.nights, 7);
      expect(w.prevReadiness, isNull);
      expect(w.asleepMinutes, 480);
    });

    test('iki hafta: ortalamalar, fark ve en iyi gece', () {
      final days = gunler(14, f: (date, i) =>
          gun(date, asleep: i < 7 ? 420 : 480, timeInBed: i < 7 ? 460 : 520));
      // Bu haftanın bir gecesi belirgin daha iyi.
      days[10].deep = 130;
      days[10].rem = 140;
      days[10].awakenings = 0;
      days[10].awakeMinutes = 0;
      MetricsEngine.run(days);
      final w = Insights.weekly(days)!;
      expect(w.asleepMinutes, 480);
      expect(w.prevAsleepMinutes, 420);
      expect(w.asleepDelta, 60);
      expect(w.bestNight.date, days[10].date);
    });

    test('filtrelenmiş listede takvimle sayar', () {
      // 14 günden 3'ü eksik: indeksle sayılsaydı haftalar kayardı.
      final hepsi = gunler(14);
      final days = [
        for (var i = 0; i < 14; i++)
          if (i != 8 && i != 9 && i != 2) hepsi[i]
      ];
      MetricsEngine.run(days);
      final w = Insights.weekly(days)!;
      expect(w.nights, 5); // 7..13 arası, 8 ve 9 eksik
    });
  });

  group('etiket günlüğü', () {
    final days = gunler(20, f: (date, i) => gun(date));

    Map<String, Set<String>> log(bool Function(int i) alkol, {int from = 0}) => {
          for (var i = from; i < 19; i++)
            gunAnahtari(days[i].date): alkol(i) ? {'alkol'} : <String>{},
        };

    test('etiket akşamın ERTESİ sabahıyla eşleşir', () {
      MetricsEngine.run(days);
      for (var i = 0; i < days.length; i++) {
        days[i].readiness = 70;
      }
      // Alkollü akşamların ertesi sabahı 50.
      final l = log((i) => i.isEven);
      for (var i = 0; i < 19; i++) {
        if (i.isEven) days[i + 1].readiness = 50;
      }
      final e = Insights.tagEffects(days, l).single;
      expect(e.tag, 'alkol');
      expect(e.withReadiness, 50);
      expect(e.withoutReadiness, 70);
      expect(e.delta, -20);
      expect(e.withDays + e.withoutDays, 19);
    });

    test('günlükte olmayan akşamlar sayılmaz', () {
      final l = log((i) => i.isEven, from: 12); // yalnızca 7 akşam bakıldı
      final e = Insights.tagEffects(days, l, minPerGroup: 3).single;
      expect(e.withDays + e.withoutDays, 7);
    });

    test('her iki grupta 4 akşam yoksa sonuç yok', () {
      expect(Insights.tagEffects(days, log((i) => i < 3)), isEmpty);
    });

    test('gece 05:00 öncesi önceki akşama yazılır', () {
      expect(Etiketler.aksam(DateTime(2026, 10, 8, 1, 30)),
          DateTime(2026, 10, 7));
      expect(Etiketler.aksam(DateTime(2026, 10, 8, 19)),
          DateTime(2026, 10, 8));
      expect(Etiketler.aksam(DateTime(2026, 11, 1, 2)),
          DateTime(2026, 10, 31));
    });
  });

  group('yatma saati', () {
    test('ihtiyaç + borç payı, kendi verimine bölünür', () {
      final days = gunler(14, f: (date, _) => gun(date, asleep: 450, timeInBed: 500));
      final p = Insights.bedtime(
          days: days, todayStrain: 10, debtMinutes: 100, wakeMinute: 7 * 60);
      expect(p.needMinutes, (Config.sleepNeedBaseMinutes + 22).round());
      expect(p.paybackMinutes, 25);
      expect(p.efficiencyFromData, isTrue);
      expect(p.efficiency, closeTo(0.9, 1e-9));
      final yatakta = ((p.needMinutes + 25) / 0.9).round();
      expect(p.inBedMinutes, yatakta);
      expect(p.bedMinute, 7 * 60 - yatakta + 1440);
      // (438 + 22 + 25) / 0.9 = 539 dk yatakta: 07:00'dan geriye 22:01.
      expect(saatDakika(p.bedMinute), '22:01');
    });

    test('borç payı en çok 60 dk', () {
      final p = Insights.bedtime(
          days: gunler(5), todayStrain: 0, debtMinutes: 900, wakeMinute: 420);
      expect(p.paybackMinutes, 60);
    });

    test('3 geceden azsa varsayılan verim', () {
      final p = Insights.bedtime(
          days: gunler(2), todayStrain: 0, debtMinutes: 0, wakeMinute: 420);
      expect(p.efficiencyFromData, isFalse);
      expect(p.efficiency, Insights.defaultEfficiency);
    });

    test('saat biçimi gece yarısını sarar', () {
      expect(saatDakika(-30), '23:30');
      expect(saatDakika(1440 + 65), '01:05');
    });
  });

  group('gece nabzı uyarısı', () {
    List<DayRecord> kur(List<double> sonlar) {
      final days = gunler(16, f: (date, i) {
        final taban = 55 + (i % 3) - 1.0; // 54..56, sd > 0
        final k = i - (16 - sonlar.length);
        return gun(date, rhr: k >= 0 ? sonlar[k] : taban);
      });
      MetricsEngine.run(days);
      return days;
    }

    test('iki gece belirgin yüksekse tetiklenir', () {
      final a = Insights.elevatedNightHr(kur([62, 63]));
      expect(a, isNotNull);
      expect(a!.deltaBpm, greaterThan(5));
    });

    test('tek gece yetmez', () {
      expect(Insights.elevatedNightHr(kur([55, 63])), isNull);
    });

    test('3 atımdan az fark tetiklemez (düşük varyans)', () {
      final days = gunler(16, f: (date, i) => gun(date, rhr: i < 14 ? 55.0 + (i % 2) * 0.2 : 57));
      MetricsEngine.run(days);
      expect(days.last.rhrZ, greaterThan(1.5));
      expect(Insights.elevatedNightHr(days), isNull);
    });

    test('taban çizgi 7 geceden kısaysa tetiklenmez', () {
      final days = gunler(6, f: (date, i) => gun(date, rhr: i < 4 ? 55.0 + i % 2 : 65));
      MetricsEngine.run(days);
      expect(Insights.elevatedNightHr(days), isNull);
    });
  });

  group('günün cümlesi', () {
    BedtimePlan plan(List<DayRecord> d) =>
        Gunluk.planFor(d, wakeMinute: 420);

    test('ilk haftada ton kalibrasyon', () {
      final days = gunler(4);
      MetricsEngine.run(days);
      expect(Gunluk.headline(days, plan(days)).ton, GunTonu.kalibrasyon);
    });

    test('gece nabzı uyarısı kısa uykudan önce gelir', () {
      final days = gunler(16, f: (date, i) {
        final g = gun(date, rhr: i >= 14 ? 63 : 55 + (i % 3) - 1.0);
        if (i == 15) {
          g.asleep = 240;
          g.timeInBed = 260;
        }
        return g;
      });
      MetricsEngine.run(days);
      final h = Gunluk.headline(days, plan(days));
      expect(h.sebep, GunSebebi.geceNabzi);
      expect(h.deger, greaterThan(5));
    });

    test('kısa uyku: ihtiyacın 90 dk altı', () {
      final days = gunler(16, f: (date, i) => i == 15
          ? gun(date, asleep: 300, timeInBed: 320)
          : gun(date, asleep: 520, timeInBed: 540));
      MetricsEngine.run(days);
      final h = Gunluk.headline(days, plan(days));
      expect(h.sebep, GunSebebi.kisaUyku);
      expect(h.deger, 300);
    });

    test('her şey normalse sebep yok', () {
      // 17 gün: son gün döngünün ortasına (HRV 52, nabız 56) denk geliyor.
      final days = gunler(17, f: (date, i) => gun(date,
          asleep: 470, timeInBed: 560, hrv: 50 + (i % 3) * 2.0,
          rhr: 55 + (i % 3) * 1.0));
      MetricsEngine.run(days);
      final h = Gunluk.headline(days, plan(days));
      expect(h.sebep, GunSebebi.yok);
    });
  });

  group('otomatik karşılaştırmalar', () {
    test('iki grupta 4 gün yoksa null', () {
      final days = gunler(10);
      expect(
          Deneyler.karsilastir('x', days,
              kosul: (d) => d.date.day == days.first.date.day,
              sonuc: (d) => 1,
              esik: 0),
          isNull);
    });

    test('gecikmeli eşleşme takvime göre', () {
      // Çift günler "koşul", ertesi günün değeri günün sırası.
      final days = gunler(12);
      final sira = {for (var i = 0; i < days.length; i++) days[i].date: i};
      final c = Deneyler.karsilastir('x', days,
          kosul: (d) => sira[d.date]!.isEven,
          sonuc: (d) => sira[d.date]!.toDouble(),
          esik: 0,
          gecikme: 1)!;
      // Çiftlerin ertesi: 1,3,5,7,9,11 -> ort 6; teklerin ertesi: 2,4,6,8,10 -> 6
      expect(c.nA, 6);
      expect(c.nB, 5);
      expect(c.a, 6);
      expect(c.b, 6);
    });

    test('adım: çok yürünen günün gecesi daha iyi uyunuyorsa görünür', () {
      final days = gunler(20, f: (date, i) => gun(date, steps: i.isEven ? 14000 : 3000));
      MetricsEngine.run(days);
      // Çok adımlı günlerin ertesi gecesini belirgin iyi yap.
      for (var i = 0; i + 1 < days.length; i++) {
        days[i + 1].sleepScore = i.isEven ? 90 : 70;
      }
      final c = Deneyler.otomatik(days).firstWhere((c) => c.key == 'adim');
      expect(c.a, 90);
      expect(c.b, 70);
      expect(c.esik, 8500);
    });
  });

  group('akşam hatırlatması', () {
    test('bugün geçmediyse bugün, geçtiyse yarın', () {
      expect(Hatirlatici.sonraki(DateTime(2026, 10, 7, 20), 22 * 60 + 15),
          DateTime(2026, 10, 7, 22, 15));
      expect(Hatirlatici.sonraki(DateTime(2026, 10, 7, 23), 22 * 60 + 15),
          DateTime(2026, 10, 8, 22, 15));
    });

    test('gece yarısını aşan saat (yatış 00:30 -> hatırlatma 00:00)', () {
      expect(Hatirlatici.sonraki(DateTime(2026, 10, 7, 21), 0),
          DateTime(2026, 10, 8, 0, 0));
      // Negatif dakika: 00:10 yatış, 30 dk önce = 23:40
      expect(Hatirlatici.sonraki(DateTime(2026, 10, 7, 21), 10 - 30),
          DateTime(2026, 10, 7, 23, 40));
    });
  });
}
