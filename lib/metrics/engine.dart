import 'dart:math' as math;

import '../config.dart';
import '../data/day_record.dart';
import 'dongu.dart';

/// Su alımı ile ERTESİ günün hazırlığı arasındaki karşılaştırma.
/// Hazırlık formülüne bir katsayı olarak GİRMEZ — etkisi gerçek ama bir
/// ağırlık rakamı verecek kadar net değil. Burada yalnızca kullanıcının
/// kendi verisinden hesaplanan fark gösterilir.
class HydrationInsight {
  /// Hedefin altında kalınan gün sayısı ve o günlerin ertesindeki hazırlık ortalaması.
  final int belowDays;
  final double belowReadiness;

  /// Hedefin tutturulduğu gün sayısı ve o günlerin ertesindeki hazırlık ortalaması.
  final int atDays;
  final double atReadiness;

  const HydrationInsight({
    required this.belowDays,
    required this.belowReadiness,
    required this.atDays,
    required this.atReadiness,
  });

  /// Pozitif olması, hedefi tutturulan günlerin ertesinin daha iyi olduğu anlamına gelir.
  double get delta => atReadiness - belowReadiness;
}

/// Ham günlük kayıtları bileşik metriklere çeviren motor.
/// Formüller prototipteki ile birebir aynı.
class MetricsEngine {
  static double clamp(double x, double a, double b) => x < a ? a : (x > b ? b : x);

  static double mean(List<double> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length;

  static double sd(List<double> a) {
    if (a.length < 2) return 0;
    final m = mean(a);
    return math.sqrt(mean(a.map((x) => (x - m) * (x - m)).toList()) + 1e-9);
  }

  /// z-skoru: önceki [win] günün ortalamasına göre konum, ve taban çizgiyi
  /// kuran gece sayısı. [log] true ise ln dönüşümü üzerinde (HRV log-normal
  /// dağılır). Taban çizgi kurulamıyorsa z = 0; o zaman sayıya bakıp girdinin
  /// skora katılıp katılmayacağına karar veren çağıran taraf.
  static (double, int) _z(
    List<DayRecord> days,
    int i,
    double? Function(DayRecord) get, {
    int win = Config.baselineWindow,
    bool log = false,
  }) {
    final prev = <double>[];
    for (var j = math.max(0, i - win); j < i; j++) {
      final v = get(days[j]);
      if (v == null || (log && v <= 0)) continue;
      prev.add(log ? math.log(v) : v);
    }
    final cur = get(days[i]);
    if (cur == null || prev.length < 3) return (0, prev.length);
    final s = sd(prev);
    if (s < 1e-6) return (0, prev.length);
    final x = log ? math.log(cur) : cur;
    return (clamp((x - mean(prev)) / s, -3.5, 3.5), prev.length);
  }

  static double median(List<double> a) {
    if (a.isEmpty) return 0;
    final s = [...a]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  // ---- uyku skoru eşikleri (0.11.0'da gerçek veriyle ayarlandı) ----

  /// Verim bileşeni bu oranda 0, [verimUst]'te 100. Eskiden 0.78..0.95
  /// idi; bileklik verimi yüksek ölçtüğü için gecelerin yarısından fazlası
  /// 100 alıyor, bileşen %20 ağırlığına rağmen bilgi taşımıyordu. 0.85
  /// klinikte "iyi uyku verimi" için kullanılan alt sınır.
  static const double verimAlt = 0.85;
  static const double verimUst = 0.98;

  /// Zamanlama: orta noktanın son 21 gecenin medyanından sapması.
  /// [zamanlamaTolerans] dakikaya kadar tam puan, [zamanlamaSifir]
  /// dakikada 0. Eskiden her dakika 1.05 puandı (95 dk = 0) ve referans
  /// ortalamaydı; tek bir uç gece ortalamayı kaydırıp sonraki üç haftayı
  /// cezalandırıyordu. İki saatlik kayma "sosyal jet lag" literatüründe
  /// belirgin bozulma eşiği.
  static const double zamanlamaTolerans = 15;
  static const double zamanlamaSifir = 120;

  static double zamanlamaPuani(double sapmaDk) => clamp(
      100 * (zamanlamaSifir - sapmaDk) / (zamanlamaSifir - zamanlamaTolerans),
      0,
      100);

  /// Gece nabız serisinin başlangıç değeri: ilk [kova] örneğin medyanı.
  static double baslangicNabzi(List<HrSample> seri, {int kova = 3}) {
    if (seri.isEmpty) return 0;
    final ilk = seri.take(kova).map((s) => s.bpm).toList()..sort();
    final n = ilk.length;
    return n.isOdd ? ilk[n ~/ 2] : (ilk[n ~/ 2 - 1] + ilk[n ~/ 2]) / 2;
  }

  /// z-skorunu 0..1 aralığına taşır.
  static double nz(double z) => clamp(0.5 + z / 3.6, 0, 1);

  /// HRV hiç gelmiyorsa (Samsung, Garmin) gece kardiyak toparlanmasının
  /// hazırlıktaki ağırlığı. HRV'nin yerini tam tutmuyor; toparlanmanın
  /// nabızdan okunabilen tek işareti olduğu için katılıyor. Veri sekmesi ve
  /// Bugün ekranı bunun yapıldığını açıkça söylüyor.
  static const double kardiyakYedekAgirlik = 0.20;

  static void run(List<DayRecord> days) {
    // Döngü: evreyi işaretle ve kişinin kendi luteal-foliküler farkını ölç.
    // Luteal günlerde nabız ve HRV bu fark kadar düzeltilip taban çizgiyle
    // karşılaştırılıyor; düzeltmesiz değerler kayıtta aynen kalıyor.
    Dongu.isaretle(days);
    final dongu = Dongu.farklar(days);
    bool luteal(DayRecord x) => dongu != null && x.donguEvresi == 'luteal';
    double? rhrDuz(DayRecord x) =>
        x.rhr == null ? null : x.rhr! - (luteal(x) ? dongu!.rhr : 0);
    double? hrvDuz(DayRecord x) => x.hrv == null
        ? null
        : x.hrv! * (luteal(x) ? math.exp(-dongu!.lnHrv) : 1);

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      d.donguDuzeltildi = luteal(d);

      final (hrvZ, hrvN) = _z(days, i, hrvDuz, log: true);
      final (rhrZ, rhrN) = _z(days, i, rhrDuz);
      final (respZ, respN) = _z(days, i, (x) => x.respiratory);
      final (tempZ, tempN) = _z(days, i,
          (x) => x.skinTempDelta == null ? null : x.skinTempDelta! + 5);
      d
        ..hrvZ = hrvZ
        ..hrvBaselineN = hrvN
        ..rhrZ = rhrZ
        ..rhrBaselineN = rhrN
        ..respZ = respZ
        ..tempZ = tempZ;

      final hrvPrev = <double>[];
      for (var j = math.max(0, i - Config.baselineWindow); j < i; j++) {
        final v = days[j].hrv;
        if (v != null && v > 0) hrvPrev.add(math.log(v));
      }
      if (hrvPrev.length >= 3) {
        d.hrvBaseline = math.exp(mean(hrvPrev));
        d.hrvBaselineSd = sd(hrvPrev);
      }
      final rhrPrev = <double>[];
      for (var j = math.max(0, i - Config.baselineWindow); j < i; j++) {
        final v = days[j].rhr;
        if (v != null) rhrPrev.add(v);
      }
      if (rhrPrev.length >= 3) d.rhrBaseline = mean(rhrPrev);

      // ---- günlük yük (TRIMP benzeri, log ölçek) ----
      const w = Config.bolgeAgirliklari;
      var raw = 0.0;
      for (var k = 1; k < 5; k++) {
        raw += d.zoneMinutes[k] * w[k];
      }
      raw += d.steps * 0.0022;
      d.strainRaw = raw;
      d.strain = clamp(6.9 * math.log(1 + raw / 24), 0, 21);

      // ---- uyku ihtiyacı ----
      final prevStrain = i > 0 ? days[i - 1].strain : 12.0;
      d.need = (Config.sleepNeedBaseMinutes + prevStrain * 2.2).round();

      // ---- uyku skoru ----
      if (d.hasSleep) {
        final cSure = clamp(d.asleep / d.need, 0, 1) * 100;
        final eff = d.timeInBed == 0 ? 0.0 : d.asleep / d.timeInBed;
        final cVerim =
            clamp((eff - verimAlt) / (verimUst - verimAlt), 0, 1) * 100;
        final restorative = d.asleep == 0 ? 0.0 : (d.deep + d.rem) / d.asleep;
        final cOnarim = clamp(restorative / 0.42, 0, 1) * 100;
        final cKesinti =
            clamp(100 - d.awakenings * 4.5 - d.awakeMinutes * 0.55, 0, 100);

        final mids = <double>[];
        for (var j = math.max(0, i - 21); j < i; j++) {
          final m = days[j].sleepMidpoint;
          if (m != null) mids.add(m);
        }
        final mid = d.sleepMidpoint;
        final cZaman = (mid == null || mids.isEmpty)
            ? 100.0
            : zamanlamaPuani((mid - median(mids)).abs());

        d.sleepParts = {
          'Sure': cSure,
          'Verim': cVerim,
          'Onarim': cOnarim,
          'Kesintisizlik': cKesinti,
          'Zamanlama': cZaman,
        };
        d.sleepScore = (cSure * 0.35 +
                cVerim * 0.20 +
                cOnarim * 0.25 +
                cKesinti * 0.10 +
                cZaman * 0.10)
            .round();
      }

      // ---- gece kardiyak toparlanma ----
      if (d.nightHr.length > 4 && d.timeInBed > 0) {
        var nadir = d.nightHr.first;
        for (final s in d.nightHr) {
          if (s.bpm < nadir.bpm) nadir = s;
        }
        d.nadirBpm = nadir.bpm;
        d.nadirMinute = nadir.minute;
        // Başlangıç: ilk 30 dakikanın (üç adet 10 dk'lık kova) medyanı. Tek
        // ilk kova, yatakta telefona bakılan birkaç dakikayla şişip düşüşü
        // olduğundan büyük gösteriyordu. Medyan tek sıçramayı yok sayar.
        final first = baslangicNabzi(d.nightHr);
        final drop = first == 0 ? 0.0 : (first - nadir.bpm) / first;
        final f = nadir.minute / d.timeInBed;
        d.cardiac = (100 *
                clamp(0.55 * clamp(drop / 0.16, 0, 1) +
                        0.45 * clamp((0.72 - f) / 0.42, 0, 1),
                    0, 1))
            .round();
      }

      // ---- hazırlık: eksik girdinin ağırlığı ötekilere dağıtılır ----
      // Taban çizgisi henüz kurulmamış girdi de eksik sayılır. Eskiden z = 0
      // ("tam ortalama") olarak katılıyordu ve yeni kullanıcı ilk iki hafta
      // hep 50 civarında, anlamsız bir skor görüyordu.
      final minN = Config.minBaselineNights;
      final weights = <double>[];
      final values = <double>[];
      void add(double weight, double? value) {
        if (value == null) return;
        weights.add(weight);
        values.add(value);
      }

      add(0.40, d.hrv == null || d.hrvBaselineN < minN ? null : nz(d.hrvZ));
      // HRV son 14 günde hiç gelmediyse: cihaz paylaşmıyor demek.
      d.kardiyakYedek = false;
      if (d.hrv == null && d.hrvBaselineN == 0) {
        final (cz, cn) = _z(days, i, (x) => x.cardiac > 0 ? x.cardiac.toDouble() : null);
        if (d.cardiac > 0 && cn >= minN) {
          add(kardiyakYedekAgirlik, nz(cz));
          d.kardiyakYedek = true;
        }
      }
      add(0.25, d.rhr == null || d.rhrBaselineN < minN ? null : nz(-d.rhrZ));
      add(0.25, d.hasSleep ? d.sleepScore / 100 : null);
      final solunumVar = d.respiratory != null && respN >= minN;
      final sicaklikVar = d.skinTempDelta != null && tempN >= minN;
      add(
          0.10,
          !solunumVar && !sicaklikVar
              ? null
              // Yalnızca biri varsa öteki sıfır z'yle ortalamayı sulandırmasın.
              : nz(-(solunumVar && sicaklikVar
                      ? (d.respZ + d.tempZ) / 2
                      : (solunumVar ? d.respZ : d.tempZ))));

      if (weights.isEmpty) {
        d.readiness = 0;
      } else {
        final total = weights.reduce((a, b) => a + b);
        var acc = 0.0;
        for (var k = 0; k < weights.length; k++) {
          acc += (weights[k] / total) * values[k];
        }
        d.readiness = (clamp(acc, 0, 1) * 100).round();
      }
    }

    // ---- uyku borcu: 14 gün, günde %7 sönümleme ----
    for (var i = 0; i < days.length; i++) {
      var debt = 0.0;
      for (var j = math.max(0, i - 13); j <= i; j++) {
        // Şekerleme borcu öder; gecenin kalitesine (uyku skoru) girmez.
        final gap = days[j].need - days[j].asleep - days[j].napMinutes;
        if (gap > 0 && days[j].hasSleep) {
          debt += gap * math.pow(0.93, i - j).toDouble();
        }
      }
      days[i].debtMinutes = debt.round();
    }

    // ---- akut / kronik yük ----
    for (var i = 0; i < days.length; i++) {
      final a = <double>[];
      for (var j = math.max(0, i - 6); j <= i; j++) {
        a.add(days[j].strain);
      }
      final c = <double>[];
      for (var j = math.max(0, i - 27); j <= i; j++) {
        c.add(days[j].strain);
      }
      days[i].acute = mean(a);
      days[i].chronic = mean(c);
      days[i].acwr =
          days[i].chronic < 0.1 ? 1.0 : days[i].acute / days[i].chronic;
      // Kronik pencerede gerçekten yük üretmiş gün sayısı. Yarısından azsa
      // oran soğuk başlangıç yüzünden şişiyor, güvenilmez.
      days[i].acwrReady = c.where((x) => x > 0).length >= 14;
    }
  }

  /// Sleep Regularity Index — ardışık günlerde uyku/uyanık durumu örtüşmesi.
  static int sri(List<DayRecord> days, {int window = 30}) {
    List<int> mask(DayRecord d) {
      final m = List<int>.filled(144, 0);
      final b = d.bedOffset;
      if (b == null || d.timeInBed <= 0) return m;
      final s = ((480 + b) / 10).round();
      final e = ((480 + b + d.timeInBed) / 10).round();
      for (var k = math.max(0, s); k < math.min(e, 144); k++) {
        m[k] = 1;
      }
      return m;
    }

    var match = 0, total = 0;
    final from = math.max(1, days.length - window);
    for (var i = from; i < days.length - 1; i++) {
      if (!days[i].hasSleep || !days[i + 1].hasSleep) continue;
      final a = mask(days[i]);
      final b = mask(days[i + 1]);
      for (var k = 0; k < 144; k++) {
        total++;
        if (a[k] == b[k]) match++;
      }
    }
    return total == 0 ? 0 : (100 * match / total).round();
  }

  /// Hastalık erken uyarısı: solunum + cilt sıcaklığı + nabız birlikte yükselmiş mi.
  ///
  /// Cilt sıcaklığı hiç gelmiyorsa (Fitbit Air solunumu yazıyor, sıcaklığı
  /// yazmıyor) solunum + nabız ikilisine bakılır. Yoksa sinyal hiçbir zaman
  /// tetiklenemiyordu.
  static bool illnessSignal(List<DayRecord> days) {
    final w = days.length < 3 ? days : days.sublist(days.length - 3);
    final sicaklikVar = w.any((d) => d.skinTempDelta != null);
    final hit = w.where((d) {
      if (d.respiratory == null || d.rhr == null) return false;
      if (d.respZ <= 1.2 || d.rhrZ <= 0.8) return false;
      return !sicaklikVar || d.tempZ > 1.0;
    }).length;
    return hit >= 2;
  }

  static bool overloadSignal(List<DayRecord> days) {
    if (days.isEmpty) return false;
    final w = days.length < 3 ? days : days.sublist(days.length - 3);
    return days.last.acwr > 1.45 && w.every((d) => d.hrvZ < 0);
  }

  /// Su kaydı olan her günü "hedefin altında" / "hedefte" diye ikiye ayırır ve
  /// ertesi günün hazırlık ortalamalarını karşılaştırır. Her iki grupta da
  /// [minPerGroup] gün yoksa null döner — az veriden çıkarım yapılmaz.
  static HydrationInsight? hydrationEffect(
    List<DayRecord> days,
    int goalMl, {
    int minPerGroup = 4,
  }) {
    final below = <double>[];
    final at = <double>[];
    for (var i = 0; i < days.length - 1; i++) {
      final d = days[i];
      final next = days[i + 1];
      // Su kaydı olmayan gün "az su içildi" demek değil; sayılmaz.
      if (d.hydrationMl <= 0) continue;
      // Ertesi günün hazırlığı uyku olmadan anlamlı değil.
      if (!next.hasSleep) continue;
      // "Ertesi gün" takvimde gerçekten ertesi gün olmalı. Liste filtrelenmiş
      // olabilir; yaz saati geçişi için saat aralığı kullanıyoruz.
      final saat = next.date.difference(d.date).inHours;
      if (saat < 20 || saat > 28) continue;
      (d.hydrationMl >= goalMl ? at : below).add(next.readiness.toDouble());
    }
    if (below.length < minPerGroup || at.length < minPerGroup) return null;
    return HydrationInsight(
      belowDays: below.length,
      belowReadiness: mean(below),
      atDays: at.length,
      atReadiness: mean(at),
    );
  }
}
