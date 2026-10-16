import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../l10n.dart';
import '../theme.dart';
import 'widgets/gauge.dart';
import 'widgets/kit.dart';

/// Uygulamanın açılış ekranı: önemli ölçümler ve onlardan hesaplanan
/// skorlar halkalar halinde, tek bakışta. Her halkaya dokununca alt sayfa
/// açılıyor: ham ölçümde son kaydın ayrıntısı, işlenmiş veride hangi
/// girdilerden hesaplandığı.
class OzetEkrani extends StatelessWidget {
  /// Uyku ya da nabız olan günler (skorlar bunlardan).
  final List<DayRecord> days;

  /// Filtrelenmemiş, takvim günü boşluksuz liste. Son ölçümü ararken bu
  /// kullanılıyor: SpO2 ya da adım, uykusuz bir günde de gelmiş olabilir.
  final List<DayRecord> allDays;

  const OzetEkrani(this.days, {required this.allDays, super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = days.last;
    final tum = allDays.isEmpty ? days : allDays;
    final bugun = tum.last;

    final islenmis = <_Halka>[
      _Halka(
        baslik: s.t('today.readiness'),
        deger: '${d.readiness}',
        t: d.readiness / 100,
        level: Levels.readiness(d.readiness),
        durum: s.t(Levels.readinessKey(d.readiness)),
        detay: () => _hazirlikDetay(context, s, d),
      ),
      if (d.hasSleep)
        _Halka(
          baslik: s.t('today.sleepScore'),
          deger: '${d.sleepScore}',
          t: d.sleepScore / 100,
          level: Levels.score(d.sleepScore),
          durum: s.t(Levels.scoreKey(d.sleepScore)),
          detay: () => _uykuSkoruDetay(context, s, d),
        ),
      _Halka(
        baslik: s.t('load.daily'),
        deger: d.strain.toStringAsFixed(1),
        t: d.strain / 21,
        renk: K.accent,
        durum: s.t('unit.of21').replaceAll('/', '/ '),
        detay: () => _yukDetay(context, s, d),
      ),
      _Halka(
        baslik: s.t('today.debt'),
        deger: _dur(s, d.debtMinutes),
        t: d.debtMinutes / 600,
        level: Levels.debt(d.debtMinutes),
        durum: s.t(Levels.debtKey(d.debtMinutes)),
        detay: () => _borcDetay(context, s, days),
      ),
      if (d.cardiac > 0)
        _Halka(
          baslik: s.t('sum.cardiac'),
          deger: '${d.cardiac}',
          t: d.cardiac / 100,
          level: Levels.score(d.cardiac),
          durum: s.t(Levels.scoreKey(d.cardiac)),
          detay: () => _kardiyakDetay(context, s, d),
        ),
      if (d.acwrReady)
        _Halka(
          baslik: s.t('today.loadRatio'),
          deger: d.acwr.toStringAsFixed(2),
          t: d.acwr / 2,
          level: Levels.acwr(d.acwr),
          durum: s.t(Levels.acwrKey(d.acwr)),
          detay: () => _oranDetay(context, s, d),
        ),
    ];

    final olcumler = <_Halka>[
      for (final o in _olcumler(s))
        if (_sonKayit(tum, o.oku) case final son?)
          _Halka(
            baslik: o.baslik,
            deger: o.bicim(o.oku(son)!),
            birim: o.birim,
            t: o.doluluk(son),
            level: o.level?.call(son),
            durum: o.durum?.call(son) ?? son.label,
            detay: () => _olcumDetay(context, s, o, tum),
          ),
      if (bugun.steps > 0)
        _Halka(
          baslik: s.t('load.steps'),
          deger: _binlik(bugun.steps),
          t: bugun.steps / Ayarlar.adimHedefi,
          renk: K.accent,
          durum: _yuzde(s, bugun.steps / Ayarlar.adimHedefi * 100),
          detay: () => _adimDetay(context, s, tum),
        ),
    ];

    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      ScreenHead('${d.label} · ${s.t('sum.eyebrow')}', s.t('tab.summary')),
      SectionLabel(s.t('sum.processed')),
      FadeUp(child: _Izgara(islenmis)),
      SectionLabel(s.t('sum.measured')),
      FadeUp(index: 1, child: _Izgara(olcumler)),
      Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter + 4, 14, K.gutter + 4, 0),
        child: Text(s.t('sum.tapHint'), style: K.note),
      ),
    ]);
  }

  // ---------------------------------------------------------------
  // Ham ölçümler

  List<_Olcum> _olcumler(S s) => [
        _Olcum(
          baslik: s.t('today.hrv'),
          tamAd: s.t('heart.hrv'),
          aciklama: s.t('sum.hrvInfo'),
          oku: (x) => x.hrv,
          bicim: (v) => v.toStringAsFixed(0),
          birim: s.t('unit.ms'),
          doluluk: (x) => x.hrvBaseline == null
              ? (x.hrv! / 120)
              : x.hrv! / (x.hrvBaseline! * 2),
          level: (x) => x.hrvBaselineN >= Config.minBaselineNights
              ? Levels.z(x.hrvZ)
              : null,
          durum: (x) => x.hrvBaselineN >= Config.minBaselineNights
              ? s.t(Levels.hrvKey(x.hrvZ))
              : null,
          taban: (x) => x.hrvBaseline,
        ),
        _Olcum(
          baslik: s.t('heart.rhr'),
          tamAd: s.t('heart.rhr'),
          aciklama: s.t('sum.rhrInfo'),
          oku: (x) => x.rhr,
          bicim: (v) => v.toStringAsFixed(0),
          birim: s.t('unit.bpm'),
          doluluk: (x) => (x.rhr! - 30) / 70,
          level: (x) => x.rhrBaselineN >= Config.minBaselineNights
              ? Levels.z(-x.rhrZ)
              : null,
          durum: (x) => x.rhrBaselineN >= Config.minBaselineNights
              ? s.t(Levels.rhrKey(x.rhrZ))
              : null,
          taban: (x) => x.rhrBaseline,
          not: (x) => x.rhrDerived ? s.t('heart.rhrDerivedSub') : null,
        ),
        _Olcum(
          baslik: s.t('sum.sleepTime'),
          tamAd: s.t('sum.sleepTime'),
          aciklama: s.t('sum.sleepTimeInfo'),
          oku: (x) => x.hasSleep ? x.asleep.toDouble() : null,
          bicim: (v) => _dur(s, v),
          doluluk: (x) => x.need == 0 ? x.asleep / 480 : x.asleep / x.need,
          level: (x) => x.need == 0
              ? null
              : (x.asleep >= x.need * 0.95
                  ? Level.good
                  : (x.asleep >= x.need * 0.8 ? Level.warn : Level.bad)),
          durum: (x) => x.need == 0 ? null : _yuzde(s, x.asleep / x.need * 100),
          not: (x) => s.t2('sum.sleepTimeNote', {
            'need': _dur(s, x.need),
            'bed': fmtClock(x.bedStart),
            'wake': fmtClock(x.wakeEnd),
          }),
        ),
        _Olcum(
          baslik: 'SpO2',
          tamAd: s.t('heart.spo2'),
          aciklama: s.t('sum.spo2Info'),
          oku: (x) => x.spo2Avg,
          bicim: (v) => v.toStringAsFixed(1),
          birim: '%',
          doluluk: (x) => (x.spo2Avg! - 85) / 15,
          level: (x) => x.spo2Avg! >= 95
              ? Level.good
              : (x.spo2Avg! >= 92 ? Level.warn : Level.bad),
          durum: (x) => s.t(x.spo2Avg! >= 95
              ? 'lvl.normal'
              : (x.spo2Avg! >= 92 ? 'lvl.watch' : 'lvl.low')),
          not: (x) => x.spo2Min == null
              ? null
              : s.t2('heart.spo2Sub', {'min': x.spo2Min!.toStringAsFixed(1)}),
        ),
        _Olcum(
          baslik: s.t('heart.resp'),
          tamAd: s.t('heart.resp'),
          aciklama: s.t('heart.respSub'),
          oku: (x) => x.respiratory,
          bicim: (v) => v.toStringAsFixed(1),
          birim: s.t('unit.perMin'),
          doluluk: (x) => (x.respiratory! - 8) / 16,
          level: (x) => Levels.dev(x.respZ.abs()),
          durum: (x) => s.t(Levels.devKey(x.respZ.abs())),
        ),
        _Olcum(
          baslik: s.t('sum.temp'),
          tamAd: s.t('heart.temp'),
          aciklama: s.t('heart.tempSub'),
          oku: (x) => x.skinTempDelta,
          bicim: (v) => sgn(v),
          birim: ' °C',
          doluluk: (x) => (x.skinTempDelta! + 1.5) / 3,
          level: (x) => Levels.dev(x.tempZ.abs()),
          durum: (x) => s.t(Levels.devKey(x.tempZ.abs())),
        ),
      ];

  void _olcumDetay(BuildContext context, S s, _Olcum o, List<DayRecord> tum) {
    final kayitlar = [
      for (final x in tum)
        if (o.oku(x) != null) x,
    ];
    final son = kayitlar.last;
    final onceki = kayitlar.length > 1 ? kayitlar[kayitlar.length - 2] : null;
    final deger = o.oku(son)!;
    final taban = o.taban?.call(son);
    final gunFarki = _gunFarki(son.date);
    final not = o.not?.call(son);
    final seri = [
      for (final x in kayitlar.length > 14
          ? kayitlar.sublist(kayitlar.length - 14)
          : kayitlar)
        o.oku(x)!,
    ];
    _detaySayfasi(
      context,
      baslik: o.tamAd,
      deger: '${o.bicim(deger)}${o.birim ?? ''}',
      level: o.level?.call(son),
      durum: o.durum?.call(son),
      aciklama: o.aciklama,
      bolumBasligi: s.t('sum.lastReading'),
      satirlar: [
        (
          s.t('sum.measuredOn'),
          gunFarki == 0
              ? '${son.label} · ${s.t('today.today')}'
              : '${son.label} · ${s.t2('sum.daysAgo', {'n': '$gunFarki'})}',
          null,
        ),
        (s.t('sum.value'), '${o.bicim(deger)}${o.birim ?? ''}', null),
        if (taban != null)
          (
            s.t('sum.baseline'),
            '${o.bicim(taban)}${o.birim ?? ''}',
            s.t('sum.baselineSub'),
          ),
        if (onceki != null)
          (
            s.t('sum.previous'),
            '${o.bicim(o.oku(onceki)!)}${o.birim ?? ''}',
            onceki.label,
          ),
        (s.t('sum.recordCount'), '${kayitlar.length}', s.t('sum.recordCountSub')),
      ],
      not: not,
      seri: seri.length > 1 ? seri : null,
      seriEtiketi: seri.length > 1
          ? s.t2('sum.lastN', {'n': '${seri.length}'})
          : null,
    );
  }

  void _adimDetay(BuildContext context, S s, List<DayRecord> tum) {
    final bugun = tum.last;
    final son7 = tum.length > 7 ? tum.sublist(tum.length - 7) : tum;
    final ort = son7.map((x) => x.steps).reduce((a, b) => a + b) / son7.length;
    _detaySayfasi(
      context,
      baslik: s.t('load.steps'),
      deger: _binlik(bugun.steps),
      aciklama: s.t('sum.stepsInfo'),
      bolumBasligi: s.t('sum.lastReading'),
      satirlar: [
        (s.t('sum.measuredOn'), '${bugun.label} · ${s.t('today.today')}', null),
        (s.t('sum.goal'), _binlik(Ayarlar.adimHedefi), null),
        (s.t('sum.avg7'), _binlik(ort.round()), null),
      ],
      seri: [for (final x in son7) x.steps.toDouble()],
      seriEtiketi: s.t2('sum.lastN', {'n': '${son7.length}'}),
    );
  }

  // ---------------------------------------------------------------
  // İşlenmiş veriler: hangi girdilerden hesaplandığı

  void _hazirlikDetay(BuildContext context, S s, DayRecord d) {
    final minN = Config.minBaselineNights;
    String katilmadi(int n) => n == 0
        ? s.t('sum.notUsedNone')
        : s.t2('sum.notUsedBaseline', {'n': '$n', 'min': '$minN'});
    final hrvVar = d.hrv != null && d.hrvBaselineN >= minN;
    final rhrVar = d.rhr != null && d.rhrBaselineN >= minN;
    final solunum = d.respiratory != null;
    final sicaklik = d.skinTempDelta != null;
    _detaySayfasi(
      context,
      baslik: s.t('today.readiness'),
      deger: '${d.readiness}',
      level: Levels.readiness(d.readiness),
      durum: s.t(Levels.readinessKey(d.readiness)),
      aciklama: s.t('sum.readinessInfo'),
      bolumBasligi: s.t('sum.inputs'),
      satirlar: [
        (
          '${s.t('today.hrv')} · ${_yuzde(s, 40)}',
          d.hrv == null ? '--' : '${d.hrv!.toStringAsFixed(0)}${s.t('unit.ms')}',
          hrvVar
              ? s.t(Levels.sapmaKey(d.hrvZ))
              : katilmadi(d.hrv == null ? 0 : d.hrvBaselineN),
        ),
        if (d.kardiyakYedek)
          (s.t('sum.cardiac'), '${d.cardiac}', s.t('sum.cardiacFallback')),
        (
          '${s.t('heart.rhr')} · ${_yuzde(s, 25)}',
          d.rhr == null ? '--' : '${d.rhr!.toStringAsFixed(0)}${s.t('unit.bpm')}',
          rhrVar
              ? s.t(Levels.sapmaKey(d.rhrZ))
              : katilmadi(d.rhr == null ? 0 : d.rhrBaselineN),
        ),
        (
          '${s.t('today.sleepScore')} · ${_yuzde(s, 25)}',
          d.hasSleep ? '${d.sleepScore}' : '--',
          d.hasSleep ? null : s.t('sum.notUsedNone'),
        ),
        (
          '${s.t('today.respTemp')} · ${_yuzde(s, 10)}',
          [
            if (solunum)
              '${d.respiratory!.toStringAsFixed(1)}${s.t('unit.perMin')}',
            if (sicaklik) '${sgn(d.skinTempDelta!)} °C',
          ].join(' · ').ifEmpty('--'),
          solunum || sicaklik ? null : s.t('sum.notUsedNone'),
        ),
      ],
      not: s.t('sum.readinessNote'),
    );
  }

  void _uykuSkoruDetay(BuildContext context, S s, DayRecord d) {
    final p = d.sleepParts;
    String puan(String k) => '${(p[k] ?? 0).round()}';
    _detaySayfasi(
      context,
      baslik: s.t('today.sleepScore'),
      deger: '${d.sleepScore}',
      level: Levels.score(d.sleepScore),
      durum: s.t(Levels.scoreKey(d.sleepScore)),
      aciklama: s.t('sum.sleepScoreInfo'),
      bolumBasligi: s.t('sum.inputs'),
      satirlar: [
        (
          '${s.t('sleep.duration')} · ${_yuzde(s, 35)}',
          puan('Sure'),
          '${_dur(s, d.asleep)} / ${_dur(s, d.need)}',
        ),
        (
          '${s.t('sleep.efficiency')} · ${_yuzde(s, 20)}',
          puan('Verim'),
          d.timeInBed == 0
              ? null
              : s.t2('sum.effSub', {
                  'pct': '${(d.asleep / d.timeInBed * 100).round()}',
                }),
        ),
        (
          '${s.t('sleep.restoration')} · ${_yuzde(s, 25)}',
          puan('Onarim'),
          '${s.t('sleep.deep')} ${_dur(s, d.deep)} · ${s.t('sleep.rem')} ${_dur(s, d.rem)}',
        ),
        (
          '${s.t('sleep.continuity')} · ${_yuzde(s, 10)}',
          puan('Kesintisizlik'),
          s.t2('sum.awakeSub', {
            'n': '${d.awakenings}',
            'min': _dur(s, d.awakeMinutes),
          }),
        ),
        (
          '${s.t('sleep.timing')} · ${_yuzde(s, 10)}',
          puan('Zamanlama'),
          '${fmtClock(d.bedStart)} – ${fmtClock(d.wakeEnd)}',
        ),
      ],
    );
  }

  void _yukDetay(BuildContext context, S s, DayRecord d) {
    final w = Config.bolgeAgirliklari;
    _detaySayfasi(
      context,
      baslik: s.t('load.daily'),
      deger: d.strain.toStringAsFixed(1),
      durum: s.t('unit.of21').replaceAll('/', '/ '),
      aciklama: s.t('sum.strainInfo'),
      bolumBasligi: s.t('sum.inputs'),
      satirlar: [
        for (var z = 1; z <= 4; z++)
          (
            '${s.t2('load.zone', {'n': '$z'})} · ×${w[z].toStringAsFixed(2)}',
            _dur(s, d.zoneMinutes[z]),
            s.t('load.zoneSub$z'),
          ),
        if (d.antrenmanlar.isNotEmpty)
          (s.t('sum.workouts'), '${d.antrenmanlar.length}', null),
      ],
      not: s.t2('sum.strainNote', {'age': '${Ayarlar.yas}'}),
    );
  }

  void _borcDetay(BuildContext context, S s, List<DayRecord> days) {
    final d = days.last;
    final son = days.length > 7 ? days.sublist(days.length - 7) : days;
    _detaySayfasi(
      context,
      baslik: s.t('today.debt'),
      deger: _dur(s, d.debtMinutes),
      level: Levels.debt(d.debtMinutes),
      durum: s.t(Levels.debtKey(d.debtMinutes)),
      aciklama: s.t('sum.debtInfo'),
      bolumBasligi: s.t('sum.inputsNights'),
      satirlar: [
        for (final x in son.reversed)
          (
            x.label,
            x.hasSleep ? _dur(s, x.asleep + x.napMinutes) : '--',
            '${s.t('sleep.need')} ${_dur(s, x.need)}',
          ),
      ],
    );
  }

  void _kardiyakDetay(BuildContext context, S s, DayRecord d) {
    final ilk = d.nightHr.isEmpty ? null : d.nightHr.first.bpm;
    _detaySayfasi(
      context,
      baslik: s.t('sleep.cardiac'),
      deger: '${d.cardiac}',
      level: Levels.score(d.cardiac),
      durum: s.t(Levels.scoreKey(d.cardiac)),
      aciklama: s.t('sum.cardiacInfo'),
      bolumBasligi: s.t('sum.inputs'),
      satirlar: [
        if (ilk != null)
          (s.t('sum.startHr'), '${ilk.round()}${s.t('unit.bpm')}', null),
        if (d.nadirBpm != null)
          (
            s.t('sum.nadirHr'),
            '${d.nadirBpm!.round()}${s.t('unit.bpm')}',
            d.nadirMinute == null || d.timeInBed == 0
                ? null
                : s.t2('sum.nadirSub', {
                    'pct': '${(d.nadirMinute! / d.timeInBed * 100).round()}',
                  }),
          ),
        (s.t('sum.hrSamples'), '${d.nightHr.length}', null),
      ],
    );
  }

  void _oranDetay(BuildContext context, S s, DayRecord d) {
    _detaySayfasi(
      context,
      baslik: s.t('today.loadRatio'),
      deger: d.acwr.toStringAsFixed(2),
      level: Levels.acwr(d.acwr),
      durum: s.t(Levels.acwrKey(d.acwr)),
      aciklama: s.t('load.ratioSub'),
      bolumBasligi: s.t('sum.inputs'),
      satirlar: [
        (s.t('load.acute'), d.acute.toStringAsFixed(1), s.t('load.acuteSub')),
        (s.t('load.chronic'), d.chronic.toStringAsFixed(1),
            s.t('load.chronicSub')),
      ],
    );
  }
}

// =====================================================================

String _dur(S s, num minutes) =>
    fmtDur(minutes, h: s.t('common.hourShort'), m: s.t('common.minShort'));

/// Türkçede yüzde işareti başta ("%40"), İngilizcede sonda ("40%").
String _yuzde(S s, num v) => s.isTr ? '%${v.round()}' : '${v.round()}%';

String _binlik(int n) {
  final t = '$n';
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
    b.write(t[i]);
  }
  return b.toString();
}

int _gunFarki(DateTime gun) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).difference(gun).inDays;
}

/// Listede değeri olan son gün.
DayRecord? _sonKayit(List<DayRecord> tum, double? Function(DayRecord) oku) {
  for (var i = tum.length - 1; i >= 0; i--) {
    if (oku(tum[i]) != null) return tum[i];
  }
  return null;
}

extension on String {
  String ifEmpty(String yedek) => isEmpty ? yedek : this;
}

/// Bir ham ölçümün nasıl okunup gösterileceği.
class _Olcum {
  final String baslik;
  final String tamAd;
  final String aciklama;
  final double? Function(DayRecord) oku;
  final String Function(double) bicim;
  final String? birim;
  final double Function(DayRecord) doluluk;
  final Level? Function(DayRecord)? level;
  final String? Function(DayRecord)? durum;
  final double? Function(DayRecord)? taban;
  final String? Function(DayRecord)? not;

  const _Olcum({
    required this.baslik,
    required this.tamAd,
    required this.aciklama,
    required this.oku,
    required this.bicim,
    this.birim,
    required this.doluluk,
    this.level,
    this.durum,
    this.taban,
    this.not,
  });
}

class _Halka {
  final String baslik;
  final String deger;
  final String? birim;
  final double t;
  final Level? level;
  final Color? renk;
  final String? durum;
  final VoidCallback detay;

  const _Halka({
    required this.baslik,
    required this.deger,
    this.birim,
    required this.t,
    this.level,
    this.renk,
    this.durum,
    required this.detay,
  });
}

/// Halkaları üçlü sütunlarda dizer.
class _Izgara extends StatelessWidget {
  final List<_Halka> halkalar;
  const _Izgara(this.halkalar);

  @override
  Widget build(BuildContext context) {
    if (halkalar.isEmpty) {
      return Kart(
          child: Text(S.of(context).t('heart.noValue'), style: K.caption));
    }
    return Kart(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: LayoutBuilder(builder: (context, c) {
        final genislik = c.maxWidth / 3;
        return Wrap(
          runSpacing: 14,
          children: [
            for (final h in halkalar)
              SizedBox(width: genislik, child: _HalkaKutusu(h)),
          ],
        );
      }),
    );
  }
}

class _HalkaKutusu extends StatelessWidget {
  final _Halka h;
  const _HalkaKutusu(this.h);

  @override
  Widget build(BuildContext context) {
    final isaret = h.renk ?? h.level?.mark ?? K.ink4;
    final murekkep = h.level?.ink ?? K.ink;
    return Basilabilir(
      onTap: h.detay,
      child: Column(children: [
        SizedBox(
          width: 84,
          height: 84,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: h.t.clamp(0.0, 1.0).toDouble()),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, v, cocuk) =>
                CustomPaint(painter: _HalkaCizer(v, isaret), child: cocuk),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RichText(
                    text: TextSpan(
                      text: h.deger,
                      style: K.hero.copyWith(fontSize: 22, color: murekkep),
                      children: [
                        if (h.birim != null)
                          TextSpan(
                              text: h.birim,
                              style: K.heroUnit.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(h.baslik,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: K.rowTitle.copyWith(fontSize: 12.5)),
        if (h.durum != null)
          Text(buyukHarf(h.durum!),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: h.level?.ink ?? K.ink3)),
      ]),
    );
  }
}

class _HalkaCizer extends CustomPainter {
  final double t;
  final Color renk;
  _HalkaCizer(this.t, this.renk);

  @override
  void paint(Canvas canvas, Size size) {
    const kalinlik = 7.0;
    final r = Rect.fromLTWH(kalinlik / 2, kalinlik / 2,
        size.width - kalinlik, size.height - kalinlik);
    canvas.drawArc(
        r,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kalinlik
          ..color = K.line2);
    if (t <= 0) return;
    canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kalinlik
          ..strokeCap = StrokeCap.round
          ..color = renk);
  }

  @override
  bool shouldRepaint(covariant _HalkaCizer old) =>
      old.t != t || old.renk != renk;
}

/// Halkaya dokununca açılan alt sayfa. Satırlar (başlık, değer, alt metin).
void _detaySayfasi(
  BuildContext context, {
  required String baslik,
  required String deger,
  Level? level,
  String? durum,
  required String aciklama,
  required String bolumBasligi,
  required List<(String, String, String?)> satirlar,
  String? not,
  List<double>? seri,
  String? seriEtiketi,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: K.bg,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(K.gutter, 0, K.gutter, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: Text(baslik, style: K.titleSmall)),
                      Text(deger,
                          style: K.hero.copyWith(
                              fontSize: 30, color: level?.ink ?? K.ink)),
                    ]),
              ),
              if (durum != null && level != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: StatusChip(level, durum),
                ),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(aciklama, style: K.caption),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Eyebrow(bolumBasligi),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: K.kartDekor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  for (var i = 0; i < satirlar.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: i == 0
                          ? null
                          : BoxDecoration(
                              border:
                                  Border(top: BorderSide(color: K.line3))),
                      child: Row(children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(satirlar[i].$1, style: K.rowTitle),
                                if (satirlar[i].$3 != null) ...[
                                  const SizedBox(height: 2),
                                  Text(satirlar[i].$3!, style: K.rowSub),
                                ],
                              ]),
                        ),
                        const SizedBox(width: 12),
                        // Uzun değer ("11 Eki · 5 gün önce") dar ekranda
                        // satırı taşırmasın: alt satıra kayıyor.
                        Flexible(
                          flex: 2,
                          child: Text(satirlar[i].$2,
                              textAlign: TextAlign.right,
                              style: K.rowValue),
                        ),
                      ]),
                    ),
                ]),
              ),
              if (seri != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Expanded(child: Eyebrow(seriEtiketi ?? '')),
                    Sparkline(seri,
                        color: level?.mark ?? K.accent,
                        width: 140,
                        height: 34),
                  ]),
                ),
              ],
              if (not != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(not, style: K.note),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
