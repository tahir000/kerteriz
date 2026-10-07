import 'dart:math' as math;

import '../config.dart';
import '../data/day_record.dart';
import 'engine.dart';

/// Takvim günü anahtarı: `2026-10-07`. Etiket günlüğü ve günler arası
/// eşleştirme bunu kullanıyor; DateTime eşitliği saat/yaz saati yüzünden
/// güvenilir değil.
String gunAnahtari(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// =====================================================================
// Haftalık özet
// =====================================================================

/// Son 7 takvim günü ile ondan önceki 7 günün karşılaştırması.
class WeeklySummary {
  /// Bu haftada uyku kaydı olan gün sayısı.
  final int nights;
  final double readiness;
  final double? prevReadiness;
  final double asleepMinutes;
  final double? prevAsleepMinutes;
  final double sleepScore;

  /// Haftanın en yüksek uyku skorlu gecesi.
  final DayRecord bestNight;

  /// Haftanın sonundaki ve başındaki uyku borcu (dakika).
  final int debtNow;
  final int debtWeekAgo;

  const WeeklySummary({
    required this.nights,
    required this.readiness,
    required this.prevReadiness,
    required this.asleepMinutes,
    required this.prevAsleepMinutes,
    required this.sleepScore,
    required this.bestNight,
    required this.debtNow,
    required this.debtWeekAgo,
  });

  double? get readinessDelta =>
      prevReadiness == null ? null : readiness - prevReadiness!;
  double? get asleepDelta =>
      prevAsleepMinutes == null ? null : asleepMinutes - prevAsleepMinutes!;
  int get debtDelta => debtNow - debtWeekAgo;
}

// =====================================================================
// Etiket günlüğü
// =====================================================================

/// Etiket günlüğündeki sabit etiketler. Sıra arayüzdeki sıradır.
/// Serbest metin yok: karşılaştırma için aynı etiketin tekrar etmesi lazım.
const List<String> etiketListesi = [
  'alkol',
  'kafein',
  'gecYemek',
  'stres',
  'gecAntrenman',
];

/// Bir etiketin, işaretlendiği akşamın ertesi sabahki hazırlığa etkisi.
class TagEffect {
  final String tag;
  final int withDays;
  final double withReadiness;
  final int withoutDays;
  final double withoutReadiness;

  const TagEffect({
    required this.tag,
    required this.withDays,
    required this.withReadiness,
    required this.withoutDays,
    required this.withoutReadiness,
  });

  /// Negatif olması, etiketli akşamların ertesinin daha kötü olduğu demek.
  double get delta => withReadiness - withoutReadiness;
}

// =====================================================================
// Yatma saati
// =====================================================================

class BedtimePlan {
  /// Gece yarısından itibaren dakika (0..1439).
  final int bedMinute;
  final int wakeMinute;

  /// Bu geceki uyku ihtiyacı (bugünkü yüke göre).
  final int needMinutes;

  /// İhtiyaca eklenen borç payı.
  final int paybackMinutes;

  /// Yatakta geçen sürenin ne kadarının uyku olduğu (0..1).
  final double efficiency;

  /// Verim kendi verinden mi geldi, yoksa varsayılan mı.
  final bool efficiencyFromData;

  const BedtimePlan({
    required this.bedMinute,
    required this.wakeMinute,
    required this.needMinutes,
    required this.paybackMinutes,
    required this.efficiency,
    required this.efficiencyFromData,
  });

  int get inBedMinutes => ((wakeMinute - bedMinute) % 1440 + 1440) % 1440;
}

/// `07:05` biçimi.
String saatDakika(int minuteOfDay) {
  final m = ((minuteOfDay % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

// =====================================================================
// Gece nabzı uyarısı
// =====================================================================

class NightHrAlert {
  /// Son iki gecenin taban çizgiye göre ortalama farkı (atım/dk).
  final double deltaBpm;
  final int nights;
  const NightHrAlert(this.deltaBpm, this.nights);
}

// =====================================================================

class Insights {
  /// Haftalık özet. Bu haftada en az [minNights] uyku kaydı yoksa null.
  ///
  /// "Hafta" takvime göre: [days] listesindeki son günden geriye 7 gün.
  /// Liste filtrelenmiş olabilir; indeksle değil tarihle sayıyoruz.
  static WeeklySummary? weekly(List<DayRecord> days, {int minNights = 4}) {
    if (days.isEmpty) return null;
    final son = days.last.date;
    final buHafta = <DayRecord>[];
    final gecenHafta = <DayRecord>[];
    for (final d in days) {
      // Saat farkı ile gün sayısı: yaz saati geçişinde 23/25 saatlik gün olur.
      final fark = (son.difference(d.date).inHours / 24).round();
      if (fark >= 0 && fark < 7) {
        buHafta.add(d);
      } else if (fark >= 7 && fark < 14) {
        gecenHafta.add(d);
      }
    }
    final uykulu = buHafta.where((d) => d.hasSleep).toList();
    if (uykulu.length < minNights) return null;
    final oncekiUykulu = gecenHafta.where((d) => d.hasSleep).toList();
    final oncekiVar = oncekiUykulu.length >= minNights;

    double ort(List<DayRecord> l, num Function(DayRecord) f) =>
        MetricsEngine.mean(l.map((d) => f(d).toDouble()).toList());

    var best = uykulu.first;
    for (final d in uykulu) {
      if (d.sleepScore > best.sleepScore) best = d;
    }

    return WeeklySummary(
      nights: uykulu.length,
      readiness: ort(uykulu, (d) => d.readiness),
      prevReadiness: oncekiVar ? ort(oncekiUykulu, (d) => d.readiness) : null,
      asleepMinutes: ort(uykulu, (d) => d.asleep),
      prevAsleepMinutes: oncekiVar ? ort(oncekiUykulu, (d) => d.asleep) : null,
      sleepScore: ort(uykulu, (d) => d.sleepScore),
      bestNight: best,
      debtNow: buHafta.last.debtMinutes,
      debtWeekAgo:
          gecenHafta.isEmpty ? buHafta.first.debtMinutes : gecenHafta.last.debtMinutes,
    );
  }

  /// Her etiket için: etiketli akşamların ertesi sabahki hazırlığı ile
  /// etiketsiz akşamlarınki.
  ///
  /// [log] anahtarı akşamın takvim günü ([gunAnahtari]), değeri o akşamın
  /// etiketleri. **Yalnızca günlükte kaydı olan akşamlar sayılır**: hiç
  /// açılmamış bir gün "alkol yoktu" demek değil, unutulmuş olabilir.
  /// Boş küme ("hiçbiri" seçildi) etiketsiz akşam olarak sayılır.
  ///
  /// Her iki grupta da [minPerGroup] gün yoksa o etiket listeye girmez.
  static List<TagEffect> tagEffects(
    List<DayRecord> days,
    Map<String, Set<String>> log, {
    int minPerGroup = 4,
  }) {
    final sabah = <String, DayRecord>{
      for (final d in days)
        if (d.hasSleep) gunAnahtari(d.date): d,
    };
    final sonuc = <TagEffect>[];
    for (final tag in etiketListesi) {
      final ile = <double>[];
      final olmadan = <double>[];
      log.forEach((aksam, etiketler) {
        final p = aksam.split('-').map(int.tryParse).toList();
        if (p.length != 3 || p.contains(null)) return;
        final ertesi =
            gunAnahtari(DateTime(p[0]!, p[1]!, p[2]! + 1));
        final d = sabah[ertesi];
        if (d == null) return;
        (etiketler.contains(tag) ? ile : olmadan).add(d.readiness.toDouble());
      });
      if (ile.length < minPerGroup || olmadan.length < minPerGroup) continue;
      sonuc.add(TagEffect(
        tag: tag,
        withDays: ile.length,
        withReadiness: MetricsEngine.mean(ile),
        withoutDays: olmadan.length,
        withoutReadiness: MetricsEngine.mean(olmadan),
      ));
    }
    return sonuc;
  }

  /// Borcun bir gecede ihtiyaca eklenen payı ve üst sınırı. Borç tek
  /// gecede kapanmaz; birkaç geceye yayılması hedefleniyor.
  static const double paybackShare = 0.25;
  static const int paybackCapMinutes = 60;

  /// Kendi verin yokken kullanılan uyku verimi.
  static const double defaultEfficiency = 0.90;

  /// Bu gece kaçta yatılmalı.
  ///
  /// İhtiyaç motorla aynı formül: taban + bugünkü yük x 2.2. Üstüne borç
  /// payı eklenir. Yatakta geçecek süre ise son 14 gecedeki **kendi
  /// verimine** bölünerek bulunur: 8 saat uyumak için 8 saat yatmak yetmez.
  static BedtimePlan bedtime({
    required List<DayRecord> days,
    required double todayStrain,
    required int debtMinutes,
    required int wakeMinute,
  }) {
    final need = (Config.sleepNeedBaseMinutes + todayStrain * 2.2).round();
    final payback =
        math.min(paybackCapMinutes, (debtMinutes * paybackShare).round());

    final verimler = <double>[];
    final from = math.max(0, days.length - 14);
    for (var i = from; i < days.length; i++) {
      final d = days[i];
      if (d.hasSleep && d.timeInBed > 0) verimler.add(d.asleep / d.timeInBed);
    }
    final veridenMi = verimler.length >= 3;
    final verim = veridenMi
        ? MetricsEngine.clamp(MetricsEngine.mean(verimler), 0.70, 0.98)
        : defaultEfficiency;

    final yatakta = ((need + payback) / verim).round();
    return BedtimePlan(
      bedMinute: ((wakeMinute - yatakta) % 1440 + 1440) % 1440,
      wakeMinute: wakeMinute,
      needMinutes: need,
      paybackMinutes: payback,
      efficiency: verim,
      efficiencyFromData: veridenMi,
    );
  }

  /// Gece nabzı iki gecedir taban çizginin belirgin üstünde mi.
  ///
  /// Solunum ve cilt sıcaklığı gelmeyen cihazlarda (Fitbit Air) eski üçlü
  /// sinyal hiç tetiklenemiyor. Tek başına dinlenme nabzı daha az özgül ama
  /// yine de en erken sinyallerden biri: hastalık, alkol, geç yemek ve aşırı
  /// yük hepsi gece nabzını yükseltir. Uyarı teşhis koymuyor, bunu söylüyor.
  ///
  /// Koşul: son iki kayıt takvimde ardışık, ikisinin de taban çizgisi en az
  /// [minBaseline] geceden kurulmuş, ikisi de z >= [minZ] ve en az
  /// [minDeltaBpm] atım yukarıda. Mutlak eşik düşük varyanslı kişilerde
  /// 1 atımlık farkın alarm olmasını engelliyor.
  static NightHrAlert? elevatedNightHr(
    List<DayRecord> days, {
    double minZ = 1.5,
    double minDeltaBpm = 3,
    int minBaseline = 7,
  }) {
    if (days.length < minBaseline + 2) return null;
    final a = days[days.length - 2];
    final b = days.last;
    final saat = b.date.difference(a.date).inHours;
    if (saat < 20 || saat > 28) return null;

    double? fark(int i) {
      final d = days[i];
      if (d.rhr == null || d.rhrBaseline == null) return null;
      if (d.rhrBaselineN < minBaseline) return null;
      final f = d.rhr! - d.rhrBaseline!;
      if (d.rhrZ < minZ || f < minDeltaBpm) return null;
      return f;
    }

    final fa = fark(days.length - 2);
    final fb = fark(days.length - 1);
    if (fa == null || fb == null) return null;
    return NightHrAlert((fa + fb) / 2, 2);
  }
}
