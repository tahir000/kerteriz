import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../data/etiketler.dart';
import '../data/hatirlatici.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../metrics/insights.dart';
import '../theme.dart';
import 'verin_ekrani.dart';
import 'widgets/charts.dart';
import 'widgets/gauge.dart';
import 'widgets/kit.dart';

List<DayRecord> _tail(List<DayRecord> d, int n) =>
    d.length <= n ? d : d.sublist(d.length - n);

String _dur(S s, num minutes) =>
    fmtDur(minutes, h: s.t('common.hourShort'), m: s.t('common.minShort'));

/// Hero bölgesi: yay göstergesi + tek paragraf açıklama.
Widget _hero({
  required String tag,
  required double value,
  required double max,
  required String display,
  String? unit,
  Level? level,
  String? levelText,
  required String caption,
  bool sayiyor = true,
}) =>
    FadeUp(
      child: Kart(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        margin: const EdgeInsets.fromLTRB(K.gutter, 2, K.gutter, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag.toUpperCase(), style: K.eyebrow),
          const SizedBox(height: 12),
          Center(
            child: ArcGauge(
              value: value,
              max: max,
              level: level,
              display: display,
              unit: unit,
              label: levelText,
              sayiyor: sayiyor,
            ),
          ),
          const SizedBox(height: 16),
          Text(caption, style: K.caption),
        ]),
      ),
    );

// =====================================================================
class TodayScreen extends StatelessWidget {
  final List<DayRecord> days;

  /// Filtrelenmemiş liste. Hidrasyon karşılaştırması "ertesi gün" ilişkisine
  /// dayanır; uyku/nabız olmayan günlerin elendiği listede days[i+1] takvimde
  /// ertesi gün olmayabilir. Verilmezse [days] kullanılır.
  final List<DayRecord>? allDays;

  const TodayScreen(this.days, {this.allDays, super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    final advLo = (d.readiness / 100 * 16 - 3).clamp(4, 17).round();
    final lvl = Levels.readiness(d.readiness);
    final recent = _tail(days, 30);

    final flags = <Widget>[];
    final nightHr = Insights.elevatedNightHr(days);
    if (MetricsEngine.illnessSignal(days)) {
      flags.add(NoteBlock(s.t('today.illness')));
    } else if (nightHr != null) {
      // Solunum ve sıcaklık gelmeyen cihazlarda tek erken sinyal bu.
      flags.add(NoteBlock(s.t2('today.nightHrHigh',
          {'delta': nightHr.deltaBpm.toStringAsFixed(0)})));
    }
    if (MetricsEngine.overloadSignal(days)) {
      flags.add(NoteBlock(
          s.t2('today.overload', {'acwr': d.acwr.toStringAsFixed(2)})));
    }

    final hydDays = allDays ?? days;
    final hydToday = hydDays.isEmpty ? d : hydDays.last;
    final plan =
        Gunluk.planFor(days, allDays: allDays, wakeMinute: Ayarlar.kalkisDk);
    final week = Insights.weekly(days);
    final baslik = Gunluk.headline(days, plan);
    // Pazartesi haftalık özet açık gelir; öteki günler tek satır.
    final pazartesi = DateTime.now().weekday == DateTime.monday;

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead('${d.label} · ${s.t('today.today')}', s.t('today.title')),
      // Günün cümlesi: ekranın tamamını okumayan biri için tek satırlık özet.
      FadeUp(child: _GununCumlesi(baslik)),
      _hero(
        tag: s.t('today.readiness'),
        value: d.readiness.toDouble(),
        max: 100,
        display: '${d.readiness}',
        level: lvl,
        levelText: s.t(Levels.readinessKey(d.readiness)),
        caption: d.hasSleep
            ? s.t2('today.caption', {
                'sleep': _dur(s, d.asleep),
                'need': _dur(s, d.need),
                'hrv': d.hrv?.toStringAsFixed(0) ?? '--',
                'rhr': d.rhr?.toStringAsFixed(0) ?? '--',
              })
            : s.t('today.captionNoSleep'),
      ),
      if (d.baselineNights < Config.baselineWindow)
        FadeUp(index: 1, child: _Kalibrasyon(d.baselineNights)),
      ...flags.map((w) => FadeUp(index: 1, child: w)),

      SectionLabel(s.t('today.forToday')),
      MetricRow(
          title: s.t('today.suggestedLoad'),
          subtitle: s.t('today.suggestedLoadSub'),
          value: '$advLo–${advLo + 4}',
          unit: s.t('unit.of21')),
      MetricRow(
          title: s.t('today.debt'),
          subtitle: s.t('today.debtSub'),
          value: _dur(s, d.debtMinutes),
          level: Levels.debt(d.debtMinutes),
          levelText: s.t(Levels.debtKey(d.debtMinutes)),
          trend: [for (final x in _tail(days, 14)) x.debtMinutes.toDouble()]),
      if (d.acwrReady)
        MetricRow(
            title: s.t('today.loadRatio'),
            subtitle: s.t('today.loadRatioSub'),
            value: d.acwr.toStringAsFixed(2),
            level: Levels.acwr(d.acwr),
            levelText: s.t(Levels.acwrKey(d.acwr)),
            extra: ZoneMeter.acwr(d.acwr))
      else
        MetricRow(
            title: s.t('today.loadRatio'),
            subtitle: s.t('load.ratioWaiting'),
            value: '--'),

      SectionLabel(s.t('today.tonight')),
      MetricRow(
        title: s.t('today.bedtime'),
        subtitle: s.t2('today.bedtimeSub', {
          'wake': saatDakika(plan.wakeMinute),
          'need': _dur(s, plan.needMinutes),
          'payback': _dur(s, plan.paybackMinutes),
          'eff': (plan.efficiency * 100).round().toString(),
        }),
        value: saatDakika(plan.bedMinute),
        onTap: () => _bilgi(
            context,
            s.t('today.bedtime'),
            plan.efficiencyFromData
                ? s.t('today.bedtimeNote')
                : s.t('today.bedtimeNoteDefault')),
      ),
      EtiketKarti(hydDays),
      MetricRow(
        title: s.t('today.water'),
        subtitle: s.t2('today.waterGoal', {'goal': '${Ayarlar.suHedefiMl}'}),
        value: '${hydToday.hydrationMl}',
        unit: s.t('unit.ml'),
        level: Levels.water(hydToday.hydrationMl, Ayarlar.suHedefiMl),
        levelText:
            s.t(Levels.waterKey(hydToday.hydrationMl, Ayarlar.suHedefiMl)),
        extra: ZoneMeter.water(hydToday.hydrationMl.toDouble(),
            Ayarlar.suHedefiMl.toDouble()),
        trend: [for (final x in _tail(hydDays, 14)) x.hydrationMl.toDouble()],
      ),

      SectionLabel(s.t('insights.section')),
      _VerinGirisi(days: days, allDays: hydDays),

      Acilir(
        anahtar: 'girdiler',
        baslik: s.t('today.inputs'),
        ozet: d.hrv != null && d.hrvBaselineN >= Config.minBaselineNights
            ? 'HRV ${sgn(d.hrvZ, digits: 1)} z'
            : null,
        children: [
          if (d.hrv != null && d.hrvBaselineN >= Config.minBaselineNights)
            MetricRow(
              title: s.t('today.hrv'),
              subtitle: s.t('today.hrvSub'),
              value: sgn(d.hrvZ),
              unit: s.t('unit.z'),
              level: Levels.z(d.hrvZ),
              levelText: s.t(Levels.zKey(d.hrvZ)),
              extra: ZoneMeter.zScore(d.hrvZ),
            )
          else
            MetricRow(
              title: s.t('today.hrv'),
              subtitle: d.hrv == null
                  ? s.t('today.hrvNone')
                  : s.t2('today.calibratingRow', {
                      'n': '${d.hrvBaselineN}',
                      'min': '${Config.minBaselineNights}',
                    }),
              value: '--',
            ),
          if (d.rhr != null && d.rhrBaselineN >= Config.minBaselineNights)
            MetricRow(
              title: s.t('today.rhr'),
              subtitle: s.t('today.rhrSub'),
              value: sgn(-d.rhrZ),
              unit: s.t('unit.z'),
              level: Levels.z(-d.rhrZ),
              levelText: s.t(Levels.zKey(-d.rhrZ)),
              extra: ZoneMeter.zScore(-d.rhrZ),
            )
          else
            MetricRow(
              title: s.t('today.rhr'),
              subtitle: d.rhr == null
                  ? s.t('today.rhrNone')
                  : s.t2('today.calibratingRow', {
                      'n': '${d.rhrBaselineN}',
                      'min': '${Config.minBaselineNights}',
                    }),
              value: '--',
            ),
          MetricRow(
            title: s.t('today.respTemp'),
            subtitle: s.t('today.respTempSub'),
            value: sgn(-(d.respZ + d.tempZ) / 2),
            unit: s.t('unit.z'),
            level: Levels.z(-(d.respZ + d.tempZ) / 2),
            levelText: s.t(Levels.zKey(-(d.respZ + d.tempZ) / 2)),
            extra: ZoneMeter.zScore(-(d.respZ + d.tempZ) / 2),
          ),
          MetricRow(
            title: s.t('today.sleepScore'),
            subtitle: s.t('today.weight25'),
            value: '${d.sleepScore}',
            unit: s.t('unit.of100'),
            level: Levels.score(d.sleepScore),
            levelText: s.t(Levels.scoreKey(d.sleepScore)),
            trend: [for (final x in _tail(days, 14)) x.sleepScore.toDouble()],
          ),
        ],
      ),

      if (week != null)
        Acilir(
          anahtar: 'hafta',
          baslik: s.t('today.week'),
          ozet: s.t2('today.weekShort',
              {'r': week.readiness.toStringAsFixed(0)}),
          baslangictaAcik: pazartesi,
          children: [
            MetricRow(
              title: s.t('today.weekReadiness'),
              subtitle: week.readinessDelta == null
                  ? s.t2('today.weekNights', {'n': '${week.nights}'})
                  : s.t2('today.weekVsPrev', {
                      'prev': week.prevReadiness!.toStringAsFixed(0),
                      'delta': sgn(week.readinessDelta!, digits: 0),
                    }),
              value: week.readiness.toStringAsFixed(0),
              unit: s.t('unit.of100'),
              level: Levels.readiness(week.readiness.round()),
              levelText: s.t(Levels.readinessKey(week.readiness.round())),
            ),
            MetricRow(
              title: s.t('today.weekSleep'),
              subtitle: week.asleepDelta == null
                  ? s.t2('today.weekSleepScore',
                      {'score': week.sleepScore.toStringAsFixed(0)})
                  : s.t2('today.weekSleepVsPrev', {
                      'score': week.sleepScore.toStringAsFixed(0),
                      'delta': (week.asleepDelta! >= 0 ? '+' : '−') +
                          _dur(s, week.asleepDelta!.abs().round()),
                    }),
              value: _dur(s, week.asleepMinutes.round()),
            ),
            MetricRow(
              title: s.t('today.weekBest'),
              subtitle: s.t2('today.weekBestSub', {
                'date': week.bestNight.label,
                'sleep': _dur(s, week.bestNight.asleep),
              }),
              value: '${week.bestNight.sleepScore}',
              unit: s.t('unit.of100'),
            ),
            MetricRow(
              title: s.t('today.weekDebt'),
              subtitle: s.t2('today.weekDebtSub',
                  {'ago': _dur(s, week.debtWeekAgo)}),
              value: (week.debtDelta >= 0 ? '+' : '−') +
                  _dur(s, week.debtDelta.abs()),
              level: week.debtDelta > 30
                  ? Level.bad
                  : (week.debtDelta < -30 ? Level.good : Level.warn),
              levelText: s.t(week.debtDelta > 30
                  ? 'today.weekDebtUp'
                  : (week.debtDelta < -30
                      ? 'today.weekDebtDown'
                      : 'today.weekDebtFlat')),
            ),
          ],
        ),

      SectionLabel(s.t('today.last30')),
      BarSeriesChart(
        bars: [
          for (final x in recent)
            Bar(x.readiness.toDouble(), level: Levels.readiness(x.readiness))
        ],
        leftLabel: recent.first.label,
        rightLabel: days.last.label,
      ),
      const LevelScale(),
      NoteBlock(s.t('today.chartNote')),
    ]);
  }
}

/// Açıklama metnini alt sayfada gösterir. Bugün ekranındaki uzun notlar
/// buraya taşındı: ekranı okuyan herkes onları her gün görmek zorunda değil.
void _bilgi(BuildContext context, String baslik, String metin) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: K.bg,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter + 4, 0, K.gutter + 4, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: K.titleSmall),
              const SizedBox(height: 10),
              Text(metin, style: K.caption),
            ]),
      ),
    ),
  );
}

/// Bugün ekranının en üstündeki tek cümle.
class _GununCumlesi extends StatelessWidget {
  final Headline h;
  const _GununCumlesi(this.h);

  static String metin(S s, Headline h) {
    final ton = s.t('headline.tone.${h.ton.name}');
    final dk = fmtDur(h.deger, h: s.t('common.hourShort'), m: s.t('common.minShort'));
    final sebep = switch (h.sebep) {
      GunSebebi.hastalik => s.t('headline.why.hastalik'),
      GunSebebi.geceNabzi => s.t2('headline.why.geceNabzi',
          {'v': h.deger.toStringAsFixed(0)}),
      GunSebebi.yuklenme => s.t2('headline.why.yuklenme',
          {'v': h.deger.toStringAsFixed(2)}),
      GunSebebi.kisaUyku => s.t2('headline.why.kisaUyku', {'v': dk}),
      GunSebebi.buyukBorc => s.t2('headline.why.buyukBorc', {'v': dk}),
      GunSebebi.dusukHrv => s.t('headline.why.dusukHrv'),
      GunSebebi.yuksekHrv => s.t('headline.why.yuksekHrv'),
      GunSebebi.iyiUyku => s.t2('headline.why.iyiUyku',
          {'v': h.deger.toStringAsFixed(0)}),
      GunSebebi.yok => null,
    };
    final yatis = s.t2('headline.bed', {'bed': saatDakika(h.plan.bedMinute)});
    return sebep == null ? '$ton. $yatis' : '$ton: $sebep. $yatis';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Kart(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      margin: const EdgeInsets.fromLTRB(K.gutter, 2, K.gutter, 8),
      child: Semantics(
        liveRegion: true,
        child: Text(metin(s, h),
            style: K.rowTitle.copyWith(fontSize: 17, height: 1.35)),
      ),
    );
  }
}

/// "Senin verin ne diyor" ekranına giriş satırı.
class _VerinGirisi extends StatelessWidget {
  final List<DayRecord> days;
  final List<DayRecord> allDays;
  const _VerinGirisi({required this.days, required this.allDays});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: Etiketler.degisti,
      builder: (context, _, _) {
        final n = VerinEkrani.hazirSayisi(days, allDays);
        return MetricRow(
          title: s.t('insights.title'),
          subtitle: n == 0
              ? s.t('insights.entryNone')
              : s.t2('insights.entry', {'n': '$n'}),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => VerinEkrani(days: days, allDays: allDays))),
        );
      },
    );
  }
}

/// İlk iki haftanın göstergesi: taban çizgi kaç geceden kuruldu, hazırlık
/// şu an hangi girdilerden hesaplanıyor.
class _Kalibrasyon extends StatelessWidget {
  final int n;
  const _Kalibrasyon(this.n);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const tam = Config.baselineWindow;
    return Kart(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.t('today.calibrating'), style: K.rowTitle)),
          Text('$n/$tam', style: K.rowValue),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(K.kapsul),
          child: LinearProgressIndicator(
            value: n / tam,
            minHeight: 6,
            backgroundColor: K.fill,
            color: K.ink2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
            n < Config.minBaselineNights
                ? s.t2('today.calibratingEarly',
                    {'min': '${Config.minBaselineNights}'})
                : s.t2('today.calibratingLate', {'full': '$tam'}),
            style: K.note),
      ]),
    );
  }
}

/// Etiket günlüğü: bu akşamın etiketleri. Karşılaştırmalar "Senin verin ne
/// diyor" ekranında; burada yalnızca giriş ve hatırlatma kısayolu var.
class EtiketKarti extends StatelessWidget {
  /// Filtrelenmemiş liste: "ertesi sabah" takvimle bulunuyor.
  final List<DayRecord> days;

  /// false ise alt sayfada gösteriliyor: kenar boşluğu ve ipucu farklı.
  final bool ozetli;
  const EtiketKarti(this.days, {this.ozetli = true, super.key});

  Future<void> _hatirlatmaAc(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    final izin = await Hatirlatici.izinIste();
    if (!izin) {
      messenger.showSnackBar(SnackBar(content: Text(s.t('notif.denied'))));
      return;
    }
    await Ayarlar.hatirlatmaYaz(true);
    messenger.showSnackBar(SnackBar(content: Text(s.t('notif.enabled'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: Etiketler.degisti,
      builder: (context, _, _) => ValueListenableBuilder<int>(
        valueListenable: Ayarlar.degisti,
        builder: (context, _, _) {
          final bugun = Etiketler.bugun();
          return Kart(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('tags.title'), style: K.rowTitle),
                  const SizedBox(height: 2),
                  Text(s.t('tags.sub'), style: K.rowSub),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in etiketListesi)
                      SecimCipi(s.t('tag.$e'),
                          secili: bugun?.contains(e) ?? false,
                          onTap: () => Etiketler.degistir(e)),
                    SecimCipi(s.t('tags.none'),
                        secili: bugun != null && bugun.isEmpty,
                        onTap: Etiketler.hicbiri),
                  ]),
                  if (!Ayarlar.hatirlatma) ...[
                    const SizedBox(height: 12),
                    Basilabilir(
                      onTap: () => _hatirlatmaAc(context),
                      child: Row(children: [
                        Icon(Icons.notifications_none, size: 18, color: K.ink2),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(s.t('tags.remind'),
                                style: K.rowSub.copyWith(color: K.ink2))),
                      ]),
                    ),
                  ],
                ]),
          );
        },
      ),
    );
  }
}

// =====================================================================
class SleepScreen extends StatelessWidget {
  final List<DayRecord> days;
  const SleepScreen(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    if (!d.hasSleep) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(s.t('state.noSleep'),
                  style: K.caption, textAlign: TextAlign.center)));
    }
    final sri = MetricsEngine.sri(days);
    final restorative = ((d.deep + d.rem) / d.asleep * 100).round();
    final last14 = _tail(days, 14);
    final stageNames = {
      'deep': s.t('sleep.deep'),
      'light': s.t('sleep.light'),
      'rem': s.t('sleep.rem'),
      'awake': s.t('sleep.awake'),
    };
    final partNames = [
      s.t('sleep.duration'),
      s.t('sleep.efficiency'),
      s.t('sleep.restoration'),
      s.t('sleep.continuity'),
      s.t('sleep.timing'),
    ];
    final weights = [35, 20, 25, 10, 10];

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead(
          '${s.t('sleep.lastNight')} · ${fmtClock(d.bedStart)}–${fmtClock(d.wakeEnd)}',
          s.t('sleep.title')),
      _hero(
        tag: s.t('sleep.score'),
        value: d.sleepScore.toDouble(),
        max: 100,
        display: '${d.sleepScore}',
        level: Levels.score(d.sleepScore),
        levelText: s.t(Levels.scoreKey(d.sleepScore)),
        caption: s.t2('sleep.caption', {
          'sleep': _dur(s, d.asleep),
          'bed': _dur(s, d.timeInBed),
          'pct': '$restorative',
        }),
      ),
      SectionLabel(s.t('sleep.throughNight')),
      FadeUp(index: 1, child: Hypnogram(d, names: stageNames)),
      SectionLabel(s.t('sleep.stages')),
      StackBar([
        MapEntry(K.stageDeep, d.deep.toDouble()),
        MapEntry(K.stageRem, d.rem.toDouble()),
        MapEntry(K.stageLight, d.light.toDouble()),
        MapEntry(K.stageWake, d.awakeMinutes.toDouble()),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 12, K.gutter, 0),
        child: Wrap(spacing: 14, runSpacing: 6, children: [
          for (final e in [
            MapEntry(K.stageDeep, '${s.t('sleep.deep')} ${_dur(s, d.deep)}'),
            MapEntry(K.stageRem, '${s.t('sleep.rem')} ${_dur(s, d.rem)}'),
            MapEntry(K.stageLight, '${s.t('sleep.light')} ${_dur(s, d.light)}'),
            MapEntry(K.stageWake, '${s.t('sleep.awake')} ${_dur(s, d.awakeMinutes)}'),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: e.key, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(e.value,
                  style: TextStyle(fontSize: 11.5, color: K.ink2)),
            ]),
        ]),
      ),
      SectionLabel(s.t('sleep.components')),
      for (var i = 0; i < d.sleepParts.length && i < partNames.length; i++)
        MetricRow(
          title: partNames[i],
          subtitle: s.t2('sleep.weight', {'w': '${weights[i]}'}),
          value: d.sleepParts.values.elementAt(i).round().toString(),
          unit: s.t('unit.of100'),
          level: Levels.score(d.sleepParts.values.elementAt(i)),
          levelText: s.t(Levels.scoreKey(d.sleepParts.values.elementAt(i))),
          extra: ZoneMeter.score(d.sleepParts.values.elementAt(i)),
        ),
      SectionLabel(s.t('sleep.deeper')),
      MetricRow(
          title: s.t('sleep.debt'),
          subtitle: s.t('sleep.debtSub'),
          value: _dur(s, d.debtMinutes),
          level: Levels.debt(d.debtMinutes),
          levelText: s.t(Levels.debtKey(d.debtMinutes)),
          trend: [for (final x in last14) x.debtMinutes.toDouble()]),
      MetricRow(
          title: s.t('sleep.sri'),
          subtitle: s.t('sleep.sriSub'),
          value: '$sri',
          unit: s.t('unit.of100'),
          level: Levels.sri(sri),
          levelText: s.t(Levels.sriKey(sri))),
      MetricRow(
          title: s.t('sleep.cardiac'),
          subtitle: s.t('sleep.cardiacSub'),
          value: '${d.cardiac}',
          unit: s.t('unit.of100'),
          level: Levels.score(d.cardiac),
          levelText: s.t(Levels.scoreKey(d.cardiac)),
          trend: [for (final x in last14) x.cardiac.toDouble()]),
      MetricRow(
          title: s.t('sleep.eff'),
          subtitle: s.t('sleep.effSub'),
          value: '${(d.asleep / d.timeInBed * 100).round()}',
          unit: '%'),
      SectionLabel(s.t('sleep.last14')),
      BarSeriesChart(
        bars: [
          for (final x in last14)
            Bar(x.asleep / 60,
                level: x.asleep >= x.need
                    ? Level.good
                    : (x.asleep >= x.need - 60 ? Level.warn : Level.bad))
        ],
        rule: d.need / 60,
        ruleLabel: s.t('sleep.need'),
        leftLabel: last14.first.label,
        rightLabel: days.last.label,
      ),
      const LevelScale(),
      SectionLabel(s.t('sleep.windowMap')),
      SleepRaster(_tail(days, 30)),
      NoteBlock(s.t('sleep.rasterNote')),
    ]);
  }
}

// =====================================================================
class LoadScreen extends StatelessWidget {
  final List<DayRecord> days;
  const LoadScreen(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    final zoneTotal = d.zoneMinutes.sublist(1).fold<double>(0, (a, x) => a + x);
    final last28 = _tail(days, 28);
    final zoneRanges = ['50–60% HRR', '60–70% HRR', '70–85% HRR', '85%+ HRR'];

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead(d.label, s.t('load.title')),
      _hero(
        tag: s.t('load.daily'),
        value: d.strain,
        max: 21,
        display: d.strain.toStringAsFixed(1),
        sayiyor: false,
        // Seviye akut/kronik orandan geliyor; oran güvenilir değilken
        // günlük yükü kırmızı "riskli" diye boyamak yanıltıcı olur.
        level: d.acwrReady ? Levels.acwr(d.acwr) : null,
        levelText: d.acwrReady ? s.t(Levels.acwrKey(d.acwr)) : null,
        caption: s.t2('load.caption', {'min': '${zoneTotal.round()}'}),
      ),
      SectionLabel(s.t('load.balance')),
      MetricRow(
          title: s.t('load.acute'),
          subtitle: s.t('load.acuteSub'),
          value: d.acute.toStringAsFixed(1),
          unit: s.t('unit.of21'),
          trend: [for (final x in last28) x.acute]),
      MetricRow(
          title: s.t('load.chronic'),
          subtitle: s.t('load.chronicSub'),
          value: d.chronic.toStringAsFixed(1),
          unit: s.t('unit.of21'),
          trend: [for (final x in last28) x.chronic]),
      if (d.acwrReady)
        MetricRow(
            title: s.t('load.ratio'),
            subtitle: s.t('load.ratioSub'),
            value: d.acwr.toStringAsFixed(2),
            level: Levels.acwr(d.acwr),
            levelText: s.t(Levels.acwrKey(d.acwr)),
            extra: ZoneMeter.acwr(d.acwr))
      else
        MetricRow(
            title: s.t('load.ratio'),
            subtitle: s.t('load.ratioWaiting'),
            value: '--'),
      SectionLabel(s.t('load.last28')),
      BarSeriesChart(
        bars: [
          for (final x in last28)
            Bar(x.strain, level: x.acwrReady ? Levels.acwr(x.acwr) : null)
        ],
        rule: d.chronic,
        ruleLabel: s.t('load.avg28'),
        leftLabel: last28.first.label,
        rightLabel: days.last.label,
      ),
      const LevelScale(),
      NoteBlock(s.t('load.zoneNote')),
      SectionLabel(s.t('load.zones')),
      StackBar([
        MapEntry(K.stageWake, d.zoneMinutes[1]),
        MapEntry(K.stageRem, d.zoneMinutes[2]),
        MapEntry(K.stageLight, d.zoneMinutes[3]),
        MapEntry(K.stageDeep, d.zoneMinutes[4]),
      ]),
      for (var k = 1; k <= 4; k++)
        MetricRow(
            title: s.t2('load.zone', {'n': '$k'}),
            subtitle: zoneRanges[k - 1],
            value: d.zoneMinutes[k].round().toString(),
            unit: s.t('unit.min')),
      MetricRow(title: s.t('load.steps'), value: d.steps.toString()),
    ]);
  }
}

// =====================================================================
class HeartScreen extends StatelessWidget {
  final List<DayRecord> days;
  const HeartScreen(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    final win = _tail(days, 45).where((x) => x.hrv != null).toList();
    final hrvVals = <double>[for (final x in win) x.hrv!];
    final hasHrv = hrvVals.length >= 2;
    final low = <double>[], high = <double>[];
    for (final x in win) {
      final b = x.hrvBaseline, sd = x.hrvBaselineSd;
      if (b != null && sd != null) {
        low.add(b * math.exp(-sd));
        high.add(b * math.exp(sd));
      } else {
        low.add(x.hrv!);
        high.add(x.hrv!);
      }
    }
    final rhrDays = days.where((x) => x.rhr != null).toList();

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead(s.t('heart.last45'), s.t('heart.title')),
      FadeUp(
        child: Kart(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          margin: const EdgeInsets.fromLTRB(K.gutter, 2, K.gutter, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('heart.hrvTag').toUpperCase(), style: K.eyebrow),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, children: [
              // Ölçüm yoksa seviye rozeti basmıyoruz: "-- ms NORMAL"
              // olmayan bir şeyi iyi gibi gösterirdi.
              Text(d.hrv?.toStringAsFixed(0) ?? '--',
                  style: K.hero.copyWith(
                      color: d.hrv == null ? K.ink3 : Levels.z(d.hrvZ).ink)),
              Text(s.t('unit.ms'), style: K.heroUnit),
              if (d.hrv != null) ...[
                const SizedBox(width: 10),
                StatusChip(Levels.z(d.hrvZ), s.t(Levels.zKey(d.hrvZ))),
              ],
            ]),
            const SizedBox(height: 14),
            Text(hasHrv ? s.t('heart.hrvCaption') : s.t('heart.hrvMissing'),
                style: K.caption),
          ]),
        ),
      ),
      if (hasHrv)
        LineSeriesChart(
          values: hrvVals,
          bandLow: low,
          bandHigh: high,
          endLevel: Levels.z(d.hrvZ),
          leftLabel: win.first.label,
          rightLabel: win.last.label,
        ),
      SectionLabel(s.t('heart.measured')),
      MetricRow(
          title: s.t('heart.hrv'),
          subtitle: d.hrv == null
              ? s.t('heart.noValue')
              : s.t2('heart.hrvSub', {'z': sgn(d.hrvZ)}),
          value: d.hrv?.toStringAsFixed(0) ?? '--',
          unit: s.t('unit.ms'),
          level: d.hrv == null ? null : Levels.z(d.hrvZ),
          levelText: d.hrv == null ? null : s.t(Levels.zKey(d.hrvZ)),
          trend: hrvVals.length > 1 ? hrvVals : null),
      MetricRow(
          title: s.t('heart.rhr'),
          subtitle: d.rhr == null
              ? s.t('heart.noValue')
              : (d.rhrDerived ? s.t('heart.rhrDerivedSub') : s.t('heart.rhrSub')),
          value: d.rhr?.toStringAsFixed(0) ?? '--',
          unit: s.t('unit.bpm'),
          level: d.rhr == null ? null : Levels.z(-d.rhrZ),
          levelText: d.rhr == null ? null : s.t(Levels.zKey(-d.rhrZ)),
          trend: [for (final x in rhrDays) x.rhr!]),
      MetricRow(
          title: s.t('heart.spo2'),
          subtitle: s.t2(
              'heart.spo2Sub', {'min': d.spo2Min?.toStringAsFixed(1) ?? '--'}),
          value: d.spo2Avg?.toStringAsFixed(1) ?? '--',
          unit: '%',
          level: d.spo2Avg == null
              ? null
              : (d.spo2Avg! >= 95
                  ? Level.good
                  : (d.spo2Avg! >= 92 ? Level.warn : Level.bad)),
          levelText: d.spo2Avg == null
              ? null
              : s.t(d.spo2Avg! >= 95
                  ? 'lvl.normal'
                  : (d.spo2Avg! >= 92 ? 'lvl.watch' : 'lvl.low'))),
      MetricRow(
          title: s.t('heart.resp'),
          subtitle: s.t('heart.respSub'),
          value: d.respiratory?.toStringAsFixed(1) ?? '--',
          unit: s.t('unit.perMin'),
          level: d.respiratory == null ? null : Levels.dev(d.respZ.abs()),
          levelText: d.respiratory == null
              ? null
              : s.t(Levels.devKey(d.respZ.abs()))),
      MetricRow(
          title: s.t('heart.temp'),
          subtitle: s.t('heart.tempSub'),
          value: d.skinTempDelta == null ? '--' : sgn(d.skinTempDelta!),
          unit: ' °C',
          level: d.skinTempDelta == null ? null : Levels.dev(d.tempZ.abs()),
          levelText: d.skinTempDelta == null
              ? null
              : s.t(Levels.devKey(d.tempZ.abs()))),
      if (rhrDays.length >= 2) ...[
        SectionLabel(s.t('heart.rhrHistory')),
        LineSeriesChart(
          values: <double>[for (final x in rhrDays) x.rhr!],
          endLevel: Levels.z(-d.rhrZ),
          leftLabel: rhrDays.first.label,
          rightLabel: rhrDays.last.label,
        ),
      ],
      NoteBlock(s.t('legal.disclaimer')),
    ]);
  }
}
