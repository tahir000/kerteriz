import 'package:flutter/material.dart';

import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../l10n.dart';
import '../metrics/gun_ici.dart';
import '../theme.dart';
import 'widgets/charts.dart';
import 'widgets/kit.dart';

/// Gün içi ayrıntı: enerji eğrisi, saat saat stres ve hesabın açıklaması.
class GunIciEkrani extends StatelessWidget {
  /// Filtrelenmemiş liste: sakin nabız referansı son günlerden kuruluyor.
  final List<DayRecord> days;
  final DayRecord bugun;

  const GunIciEkrani({super.key, required this.days, required this.bugun});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final o = GunIci.ozet(days, bugun, hrMax: Ayarlar.hrMax);
    String dur(num m) =>
        fmtDur(m, h: s.t('common.hourShort'), m: s.t('common.minShort'));

    // Saatlik stres: dört dilimin ortalaması, ölçülebilen dilim yoksa boş.
    final saatlik = <Bar>[];
    var ilkSaat = 24, sonSaat = -1;
    if (o != null) {
      for (var h = 0; h <= o.sonVeriDilimi ~/ 4; h++) {
        final d = [
          for (var b = h * 4; b < h * 4 + 4 && b <= o.sonVeriDilimi; b++)
            if (o.stres[b] != null) o.stres[b]!
        ];
        if (d.isEmpty) continue;
        if (h < ilkSaat) ilkSaat = h;
        sonSaat = h;
        final v = d.reduce((a, b) => a + b) / d.length;
        saatlik.add(Bar(v * 100, level: Levels.stres(v)));
      }
    }

    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 44), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(K.gutter - 6, 8, K.gutter, 0),
            child: Row(children: [
              Basilabilir(
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back, size: 22, color: K.ink),
                ),
              ),
            ]),
          ),
          ScreenHead(bugun.label, s.t('intraday.title'), ayarlar: false),
          if (o == null)
            NoteBlock(s.t('intraday.none'))
          else ...[
            if (o.enerji != null) ...[
              SectionLabel(s.t('intraday.energy')),
              LineSeriesChart(
                values: o.enerji!.degerler,
                endLevel: Levels.readiness(o.enerji!.simdi.round()),
                leftLabel: GunIci.dilimSaati(o.enerji!.ilkDilim),
                rightLabel: GunIci.dilimSaati(o.sonVeriDilimi + 1),
              ),
              MetricRow(
                title: s.t('intraday.energyStart'),
                subtitle: s.t('intraday.energyStartSub'),
                value: o.enerji!.baslangic.toStringAsFixed(0),
              ),
              MetricRow(
                title: s.t('intraday.drainLoad'),
                value: '−${o.enerji!.yukKaybi.toStringAsFixed(0)}',
              ),
              MetricRow(
                title: s.t('intraday.drainStress'),
                value: '−${o.enerji!.stresKaybi.toStringAsFixed(0)}',
              ),
              MetricRow(
                title: s.t('intraday.drainAwake'),
                value: '−${o.enerji!.uyaniklikKaybi.toStringAsFixed(0)}',
              ),
              NoteBlock(s.t('intraday.energyNote')),
            ],
            SectionLabel(s.t('intraday.stressHourly')),
            if (saatlik.isEmpty)
              NoteBlock(s.t('intraday.stressNone'))
            else
              BarSeriesChart(
                bars: saatlik,
                leftLabel: '${ilkSaat.toString().padLeft(2, '0')}:00',
                rightLabel: '${sonSaat.toString().padLeft(2, '0')}:00',
              ),
            MetricRow(
              title: s.t('intraday.highStress'),
              value: dur(o.yuksekStresDk),
            ),
            MetricRow(
              title: s.t('intraday.calmHr'),
              subtitle: s.t('intraday.calmHrSub'),
              value: o.sakinNabiz.toStringAsFixed(0),
              unit: s.t('unit.bpm'),
            ),
            NoteBlock(s.t('intraday.stressNote')),
          ],
        ]),
      ),
    );
  }
}
