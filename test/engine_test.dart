import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/config.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/metrics/engine.dart';

import 'helpers.dart';

void main() {
  group('hazırlık', () {
    test('sabit girdilerle z = 0, ağırlıklar eksik solunum/sıcaklığa göre dağılır',
        () {
      final days = gunler(20);
      MetricsEngine.run(days);
      final d = days.last;
      expect(d.hrvZ, 0);
      expect(d.rhrZ, 0);
      // Solunum + sıcaklık yok: 0.10 ağırlık ötekilere oransal dağılır.
      final beklenen =
          (0.40 * 0.5 + 0.25 * 0.5 + 0.25 * d.sleepScore / 100) / 0.90;
      expect(d.readiness, (beklenen * 100).round());
    });

    test('HRV yoksa skor nabız ve uykudan kurulur', () {
      final days = gunler(20, f: (date, _) => gun(date, hrv: null));
      MetricsEngine.run(days);
      final d = days.last;
      final beklenen = (0.25 * 0.5 + 0.25 * d.sleepScore / 100) / 0.50;
      expect(d.readiness, (beklenen * 100).round());
    });

    test('hiç girdi yoksa hazırlık 0', () {
      final days = gunler(5,
          f: (date, _) => gun(date, asleep: 0, hrv: null, rhr: null));
      MetricsEngine.run(days);
      expect(days.last.readiness, 0);
    });

    test('yüksek HRV hazırlığı yükseltir, yüksek nabız düşürür', () {
      List<int> calis({double? hrvSon, double? rhrSon}) {
        final days = gunler(20, f: (date, i) {
          // Taban çizginin sıfır olmayan bir sapması olsun.
          final g = gun(date, hrv: 50 + (i % 3) * 2.0, rhr: 55 + (i % 3) * 1.0);
          if (i == 19) {
            if (hrvSon != null) g.hrv = hrvSon;
            if (rhrSon != null) g.rhr = rhrSon;
          }
          return g;
        });
        MetricsEngine.run(days);
        return [days.last.readiness];
      }

      final normal = calis()[0];
      expect(calis(hrvSon: 70)[0], greaterThan(normal));
      expect(calis(rhrSon: 65)[0], lessThan(normal));
    });

    test('taban çizgi 7 geceden azsa kalp girdileri skora katılmaz', () {
      final days = gunler(10, f: (date, i) =>
          gun(date, hrv: 50 + (i % 3) * 2.0, rhr: 55 + (i % 3) * 1.0));
      MetricsEngine.run(days);
      // 4. gün: önceki 3 gece var, z hesaplanabiliyor ama skora girmemeli.
      expect(days[3].hrvBaselineN, 3);
      expect(days[3].readiness, days[3].sleepScore);
      // 8. gün: 7 gece, artık kalp girdileri de var.
      expect(days[7].hrvBaselineN, Config.minBaselineNights);
      final d = days[7];
      final beklenen = (0.40 * MetricsEngine.nz(d.hrvZ) +
              0.25 * MetricsEngine.nz(-d.rhrZ) +
              0.25 * d.sleepScore / 100) /
          0.90;
      expect(d.readiness, (beklenen * 100).round());
      expect(days.last.baselineNights, 9);
    });

    test('yalnızca cilt sıcaklığı varsa solunumun sıfırı ortalamayı sulandırmaz',
        () {
      final days = gunler(20, f: (date, i) {
        final g = gun(date);
        g.skinTempDelta = i == 19 ? 1.5 : (i % 3) * 0.1;
        return g;
      });
      MetricsEngine.run(days);
      final d = days.last;
      final beklenen = (0.40 * 0.5 +
              0.25 * 0.5 +
              0.25 * d.sleepScore / 100 +
              0.10 * MetricsEngine.nz(-d.tempZ)) /
          1.0;
      expect(d.readiness, (beklenen * 100).round());
    });

    test('HRV taban çizgisi logaritmik: geometrik ortalama', () {
      final degerler = [20.0, 40.0, 80.0];
      final days = gunler(4, f: (date, i) => gun(date, hrv: i < 3 ? degerler[i] : 40));
      MetricsEngine.run(days);
      // ln uzayında ortalama: exp((ln20+ln40+ln80)/3) = 40; aritmetik 46,7 olurdu.
      expect(days.last.hrvBaseline, closeTo(40, 1e-6));
    });
  });

  group('uyku', () {
    test('ihtiyaç dünkü yüke göre; ilk gün varsayılan 12', () {
      final days = gunler(3);
      MetricsEngine.run(days);
      expect(days[0].need, (Config.sleepNeedBaseMinutes + 12 * 2.2).round());
      expect(days[1].need,
          (Config.sleepNeedBaseMinutes + days[0].strain * 2.2).round());
    });

    test('uyku skoru 0..100 arasında ve kısa uyku düşürür', () {
      final days = gunler(15, f: (date, i) =>
          i == 14 ? gun(date, asleep: 240, timeInBed: 300) : gun(date));
      MetricsEngine.run(days);
      for (final d in days) {
        expect(d.sleepScore, inInclusiveRange(0, 100));
      }
      expect(days.last.sleepScore, lessThan(days[13].sleepScore));
    });

    test('uyku borcu günde %7 sönümlenir', () {
      // İlk gün ihtiyacın 120 dk altında, sonra ihtiyacı fazlasıyla karşılayan geceler.
      final days = gunler(10, f: (date, i) =>
          i == 0 ? gun(date, asleep: 300, timeInBed: 330) : gun(date, asleep: 600, timeInBed: 640));
      MetricsEngine.run(days);
      final ilkAcik = days[0].need - days[0].asleep;
      expect(days[0].debtMinutes, ilkAcik);
      expect(days[5].debtMinutes, (ilkAcik * math.pow(0.93, 5)).round());
    });

    test('uyku borcu 14 günden eskiyi saymaz', () {
      final days = gunler(16, f: (date, i) =>
          i == 0 ? gun(date, asleep: 300, timeInBed: 330) : gun(date, asleep: 600, timeInBed: 640));
      MetricsEngine.run(days);
      expect(days[13].debtMinutes, greaterThan(0));
      expect(days[14].debtMinutes, 0);
    });

    test('aynı saatte uyunan geceler için SRI 100', () {
      final days = gunler(10);
      MetricsEngine.run(days);
      expect(MetricsEngine.sri(days), 100);
    });
  });

  group('yük', () {
    test('hareketsiz gün 0, yük 21 ile sınırlı', () {
      final days = gunler(2, f: (date, i) => i == 0
          ? gun(date, steps: 0)
          : gun(date, steps: 100000, zoneMinutes: [0, 300, 300, 300, 300]));
      MetricsEngine.run(days);
      expect(days[0].strain, 0);
      expect(days[1].strain, 21);
    });

    test('ACWR ancak 14 yüklü günden sonra hazır', () {
      final days = gunler(20);
      MetricsEngine.run(days);
      expect(days[12].acwrReady, isFalse);
      expect(days[13].acwrReady, isTrue);
      // Sabit yükte oran 1.
      expect(days.last.acwr, closeTo(1, 1e-9));
    });
  });

  group('kardiyak toparlanma', () {
    List<HrSample> seri(List<double> bpm) =>
        [for (var i = 0; i < bpm.length; i++) HrSample(i * 10, bpm[i])];

    test('başlangıç ilk 30 dakikanın medyanı', () {
      expect(MetricsEngine.baslangicNabzi(seri([90, 62, 60, 50])), 62);
      expect(MetricsEngine.baslangicNabzi(seri([60, 64])), 62);
      expect(MetricsEngine.baslangicNabzi([]), 0);
    });

    test('yatağa girerken tek sıçrama skoru şişirmez', () {
      // Aynı gece; birinde ilk 10 dakika telefonla 90 atım.
      final normal = <double>[56, 55, 56, 54, 53, 52, 52, 53, 54, 55, 55, 56];
      final sicramali = <double>[70, ...normal.skip(1)];
      int calis(List<double> bpm) {
        final days = gunler(1,
            f: (date, _) => gun(date, timeInBed: 120, nightHr: seri(bpm)));
        MetricsEngine.run(days);
        return days.single.cardiac;
      }

      expect((calis(sicramali) - calis(normal)).abs(), lessThanOrEqualTo(3));
    });
  });

  group('sinyaller', () {
    test('solunum ve sıcaklık yokken eski hastalık sinyali tetiklenmez', () {
      final days = gunler(20, f: (date, i) => gun(date, rhr: i > 16 ? 70 : 55));
      MetricsEngine.run(days);
      expect(MetricsEngine.illnessSignal(days), isFalse);
    });

    test('su karşılaştırması az veriyle null, yeterli veriyle iki grup', () {
      final az = gunler(6, f: (date, i) => gun(date, hydrationMl: 3000));
      MetricsEngine.run(az);
      expect(MetricsEngine.hydrationEffect(az, 2500), isNull);

      final days = gunler(20, f: (date, i) =>
          gun(date, hydrationMl: i.isEven ? 3000 : 1000));
      MetricsEngine.run(days);
      final h = MetricsEngine.hydrationEffect(days, 2500)!;
      expect(h.atDays + h.belowDays, 19);
    });
  });
}
