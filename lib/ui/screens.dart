import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/day_record.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../theme.dart';
import 'widgets/charts.dart';
import 'widgets/gauge.dart';
import 'widgets/kit.dart';

List<DayRecord> _tail(List<DayRecord> d, int n) =>
    d.length <= n ? d : d.sublist(d.length - n);

String _dur(S s, num minutes) =>
    fmtDur(minutes, h: s.t('common.hourShort'), m: s.t('common.minShort'));

/// Hero bolgesi: yay gostergesi + tek paragraf aciklama.
Widget _hero({
  required String tag,
  required double value,
  required double max,
  required String display,
  String? unit,
  required Level level,
  required String levelText,
  required String caption,
}) =>
    FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 4, K.gutter, 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag.toUpperCase(), style: K.eyebrow),
          const SizedBox(height: 14),
          Center(
            child: ArcGauge(
              value: value,
              max: max,
              level: level,
              display: display,
              unit: unit,
              label: levelText,
            ),
          ),
          const SizedBox(height: 18),
          Text(caption, style: K.caption),
        ]),
      ),
    );

// =====================================================================
class TodayScreen extends StatelessWidget {
  final List<DayRecord> days;
  const TodayScreen(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    final advLo = (d.readiness / 100 * 16 - 3).clamp(4, 17).round();
    final lvl = Levels.readiness(d.readiness);
    final recent = _tail(days, 30);

    final flags = <Widget>[];
    if (MetricsEngine.illnessSignal(days)) {
      flags.add(NoteBlock(s.t('today.illness')));
    }
    if (MetricsEngine.overloadSignal(days)) {
      flags.add(NoteBlock(
          s.t2('today.overload', {'acwr': d.acwr.toStringAsFixed(2)})));
    }

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead('${d.label} · ${s.t('today.today')}', s.t('today.title')),
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
      ...flags.map((w) => FadeUp(index: 1, child: w)),
      SectionLabel(s.t('today.inputs')),
      MetricRow(
        title: s.t('today.hrv'),
        subtitle: s.t('today.hrvSub'),
        value: sgn(d.hrvZ),
        unit: s.t('unit.z'),
        level: Levels.z(d.hrvZ),
        levelText: s.t(Levels.zKey(d.hrvZ)),
        extra: ZoneMeter.zScore(d.hrvZ),
      ),
      MetricRow(
        title: s.t('today.rhr'),
        subtitle: s.t('today.rhrSub'),
        value: sgn(-d.rhrZ),
        unit: s.t('unit.z'),
        level: Levels.z(-d.rhrZ),
        levelText: s.t(Levels.zKey(-d.rhrZ)),
        extra: ZoneMeter.zScore(-d.rhrZ),
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
      MetricRow(
          title: s.t('today.loadRatio'),
          subtitle: s.t('today.loadRatioSub'),
          value: d.acwr.toStringAsFixed(2),
          level: Levels.acwr(d.acwr),
          levelText: s.t(Levels.acwrKey(d.acwr)),
          extra: ZoneMeter.acwr(d.acwr)),
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
                  style: const TextStyle(fontSize: 11.5, color: K.ink2)),
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
        level: Levels.acwr(d.acwr),
        levelText: s.t(Levels.acwrKey(d.acwr)),
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
      MetricRow(
          title: s.t('load.ratio'),
          subtitle: s.t('load.ratioSub'),
          value: d.acwr.toStringAsFixed(2),
          level: Levels.acwr(d.acwr),
          levelText: s.t(Levels.acwrKey(d.acwr)),
          extra: ZoneMeter.acwr(d.acwr)),
      SectionLabel(s.t('load.last28')),
      BarSeriesChart(
        bars: [for (final x in last28) Bar(x.strain, level: Levels.acwr(x.acwr))],
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.gutter, 4, K.gutter, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('heart.hrvTag').toUpperCase(), style: K.eyebrow),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, children: [
              Text(d.hrv?.toStringAsFixed(0) ?? '--',
                  style: K.hero.copyWith(color: Levels.z(d.hrvZ).ink)),
              Text(s.t('unit.ms'), style: K.heroUnit),
              const SizedBox(width: 10),
              StatusChip(Levels.z(d.hrvZ), s.t(Levels.zKey(d.hrvZ))),
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
          subtitle: s.t2('heart.hrvSub', {'z': sgn(d.hrvZ)}),
          value: d.hrv?.toStringAsFixed(0) ?? '--',
          unit: s.t('unit.ms'),
          level: Levels.z(d.hrvZ),
          levelText: s.t(Levels.zKey(d.hrvZ)),
          trend: hrvVals.length > 1 ? hrvVals : null),
      MetricRow(
          title: s.t('heart.rhr'),
          subtitle:
              d.rhrDerived ? s.t('heart.rhrDerivedSub') : s.t('heart.rhrSub'),
          value: d.rhr?.toStringAsFixed(0) ?? '--',
          unit: s.t('unit.bpm'),
          level: Levels.z(-d.rhrZ),
          levelText: s.t(Levels.zKey(-d.rhrZ)),
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
