import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../data/day_record.dart';
import '../data/health_repository.dart';
import '../l10n.dart';
import '../theme.dart';
import 'widgets/gauge.dart';
import 'widgets/kit.dart';

/// Health Connect'ten gercekte ne geldigini gosteren tani ekrani.
/// Bir metrik bos cikiyorsa sebebi burada gorunur: izin mi yok, veri mi yok.
class CoverageScreen extends StatelessWidget {
  final HealthRepository repo;
  final List<DayRecord> days;
  final VoidCallback onReload;

  const CoverageScreen({
    super.key,
    required this.repo,
    required this.days,
    required this.onReload,
  });

  static const _typeKeys = <HealthDataType, String>{
    HealthDataType.SLEEP_DEEP: 'type.deepSleep',
    HealthDataType.SLEEP_LIGHT: 'type.lightSleep',
    HealthDataType.SLEEP_REM: 'type.remSleep',
    HealthDataType.SLEEP_AWAKE: 'type.awake',
    HealthDataType.SLEEP_SESSION: 'type.sleepSession',
    HealthDataType.HEART_RATE: 'type.heartRate',
    HealthDataType.RESTING_HEART_RATE: 'type.restingHr',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'type.hrv',
    HealthDataType.RESPIRATORY_RATE: 'type.respiratory',
    HealthDataType.BLOOD_OXYGEN: 'type.spo2',
    HealthDataType.SKIN_TEMPERATURE: 'type.skinTemp',
    HealthDataType.STEPS: 'type.steps',
  };

  /// Skorlarda dogrudan agirligi olan tipler — bos olmalari onemli.
  static const _critical = {
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_DEEP,
  };

  int _n(HealthDataType t) => repo.rawCounts[t] ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final withSleep = days.where((d) => d.hasSleep).length;
    final withHrv = days.where((d) => d.hrv != null).length;
    final withRhr = days.where((d) => d.rhr != null).length;
    final derivedRhr = days.where((d) => d.rhrDerived).length;
    final withResp = days.where((d) => d.respiratory != null).length;
    final withSpo2 = days.where((d) => d.spo2Avg != null).length;
    final illnessOk =
        withResp > 0 || days.any((d) => d.skinTempDelta != null);
    final loadOk = _n(HealthDataType.HEART_RATE) > 0;
    final readyOk = withHrv > 0 || withRhr > 0 || withSleep > 0;
    final missing = _typeKeys.keys
        .where((t) => _n(t) == 0 && _critical.contains(t))
        .toList();
    final total = repo.rawCounts.values.fold<int>(0, (a, b) => a + b);

    String range() {
      final a = repo.firstPoint, b = repo.lastPoint;
      if (a == null || b == null) return s.t('data.noRange');
      String f(DateTime d) => '${d.day}.${d.month}.${d.year}';
      return '${f(a)} — ${f(b)}';
    }

    final sleepLevel =
        withSleep >= 14 ? Level.good : (withSleep >= 3 ? Level.warn : Level.bad);

    return ListView(padding: const EdgeInsets.only(bottom: 48), children: [
      ScreenHead(s.t('data.source'), s.t('data.title')),
      FadeUp(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.gutter, 4, K.gutter, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('data.nightsWithSleep').toUpperCase(), style: K.eyebrow),
            const SizedBox(height: 14),
            Center(
              child: ArcGauge(
                value: withSleep.toDouble(),
                max: 14,
                level: sleepLevel,
                display: '$withSleep',
                label: s.t(withSleep >= 14
                    ? 'lvl.enough'
                    : (withSleep >= 3 ? 'lvl.building' : 'lvl.tooFew')),
              ),
            ),
            const SizedBox(height: 18),
            Text(
                withSleep >= 14
                    ? s.t('data.enoughCaption')
                    : s.t('data.thinCaption'),
                style: K.caption),
          ]),
        ),
      ),

      SectionLabel(s.t('data.summary')),
      MetricRow(
          title: s.t('data.requested'),
          subtitle: s.t('data.requestedSub'),
          value: '${repo.requestedDays}',
          unit: s.t('unit.day')),
      MetricRow(
          title: s.t('data.range'),
          subtitle: range(),
          value: '$total',
          unit: s.t('unit.record')),
      MetricRow(
          title: s.t('data.hrvNights'),
          subtitle: s.t('data.hrvNightsSub'),
          value: '$withHrv',
          level: withHrv > 0 ? Level.good : Level.bad,
          levelText: s.t(withHrv > 0 ? 'lvl.flowing' : 'common.none')),
      MetricRow(
          title: s.t('data.rhrDays'),
          subtitle: derivedRhr > 0
              ? s.t2('data.rhrDerivedSub', {'n': '$derivedRhr'})
              : s.t('data.rhrDaysSub'),
          value: '$withRhr',
          level: withRhr > 0 ? Level.good : Level.bad,
          levelText: s.t(withRhr > 0
              ? (derivedRhr > 0 ? 'lvl.derived' : 'lvl.flowing')
              : 'common.none')),

      SectionLabel(s.t('data.capabilities')),
      MetricRow(
          title: s.t('data.capReadiness'),
          subtitle: s.t('data.capReadinessSub'),
          value: s.t(readyOk ? 'common.yes' : 'common.no'),
          level: readyOk ? Level.good : Level.bad,
          levelText: s.t(withHrv > 0 ? 'lvl.full' : 'lvl.partial')),
      MetricRow(
          title: s.t('data.capSleep'),
          subtitle: s.t('data.capSleepSub'),
          value: s.t(withSleep > 0 ? 'common.yes' : 'common.no'),
          level: withSleep > 0 ? Level.good : Level.bad,
          levelText: s.t(withSleep > 0 ? 'lvl.working' : 'lvl.noData')),
      MetricRow(
          title: s.t('data.capLoad'),
          subtitle: s.t('data.capLoadSub'),
          value: s.t(loadOk ? 'common.yes' : 'common.no'),
          level: loadOk ? Level.good : Level.bad,
          levelText: s.t(loadOk ? 'lvl.working' : 'lvl.noData')),
      MetricRow(
          title: s.t('data.capIllness'),
          subtitle: s.t('data.capIllnessSub'),
          value: s.t(illnessOk ? 'common.yes' : 'common.no'),
          level: illnessOk ? Level.good : Level.warn,
          levelText: s.t(illnessOk ? 'lvl.on' : 'lvl.off')),
      MetricRow(
          title: s.t('data.capSpo2'),
          subtitle: s.t('data.capSpo2Sub'),
          value: s.t(withSpo2 > 0 ? 'common.yes' : 'common.no'),
          level: withSpo2 > 0 ? Level.good : Level.warn,
          levelText: s.t(withSpo2 > 0 ? 'lvl.on' : 'lvl.off')),

      SectionLabel(s.t('data.byType')),
      for (final e in _typeKeys.entries)
        MetricRow(
          title: s.t(e.value),
          subtitle: _critical.contains(e.key) ? s.t('data.usedInScores') : null,
          value: '${_n(e.key)}',
          level: _n(e.key) > 0
              ? Level.good
              : (_critical.contains(e.key) ? Level.bad : Level.warn),
          levelText: s.t(_n(e.key) > 0 ? 'lvl.present' : 'lvl.empty'),
        ),
      const LevelScale(),

      if (derivedRhr > 0) NoteBlock(s.t('data.derivedNote')),
      if (missing.isNotEmpty) NoteBlock(s.t('data.missingNote')),
      NoteBlock(s.t('data.privacyNote')),

      Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 26, K.gutter, 0),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: K.ink,
              side: const BorderSide(color: K.line),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: onReload,
          child: Text(s.t('common.retry'),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    ]);
  }
}
