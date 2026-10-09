import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../data/health_repository.dart';
import '../data/regl_kayitlari.dart';
import '../l10n.dart';
import '../metrics/dongu.dart';
import '../metrics/insights.dart';
import '../theme.dart';
import 'widgets/charts.dart';
import 'widgets/gauge.dart';
import 'widgets/kit.dart';

/// Döngü sekmesi. Ayarlarda "Kadın" seçilince alt menüde açılıyor.
///
/// Regl günleri iki yerden geliyor: Health Connect'e yazan uygulamalar (Flo,
/// Clue, Samsung Health) ve bu ekrandaki takvim. Takvimden işaretlenen
/// günler yalnızca telefonda tutuluyor.
///
/// Kerteriz bir döngü takip uygulaması değil: doğurganlık ya da yumurtlama
/// tahmini vermiyor. Döngüyü, hazırlık skorunu doğru okumak için kullanıyor.
class DonguEkrani extends StatelessWidget {
  /// Filtrelenmemiş liste (regl kaydı olan ama uyku/nabız olmayan gün de var).
  final List<DayRecord> days;
  const DonguEkrani({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bas = Dongu.baslangiclar(days);
    final uzun = Dongu.uzunluk(bas);
    final d = days.isEmpty ? null : days.last;
    final fark = Ayarlar.donguDuzeltme ? Dongu.farklar(days) : null;
    final ilerleme = Dongu.ilerleme(days);
    final gun = d?.donguGunu;

    // Son döngüler: başlangıç ve bir sonrakine kadar geçen gün.
    final dongular = <(DateTime, int?)>[
      for (var i = bas.length - 1; i >= 0 && i >= bas.length - 4; i--)
        (
          bas[i],
          i + 1 < bas.length
              ? (bas[i + 1].difference(bas[i]).inHours / 24).round()
              : null
        )
    ];

    // Son 56 günün dinlenme nabzı: luteal yükselmesi gözle görülsün.
    final son56 = days.length <= 56 ? days : days.sublist(days.length - 56);
    final nabiz = [for (final x in son56) if (x.rhr != null) x.rhr!];

    return ListView(padding: const EdgeInsets.only(bottom: 112), children: [
      ScreenHead(d?.label ?? '', s.t('cycle.screenTitle')),
      if (gun == null)
        _BosDurum()
      else ...[
        FadeUp(
          child: Kart(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            margin: const EdgeInsets.fromLTRB(K.gutter, 2, K.gutter, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(buyukHarf(s.t('cycle.title')), style: K.eyebrow),
              const SizedBox(height: 12),
              Center(
                child: ArcGauge(
                  value: gun.toDouble().clamp(0, uzun.toDouble()),
                  max: uzun.toDouble(),
                  display: '$gun',
                  unit: '/$uzun',
                  // Kısa ad: uzun açıklama yayın çizgisine biniyordu.
                  label: s.t('cycle.phaseShort.${d!.donguEvresi}'),
                  renk: K.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(s.t('cycle.phaseNote.${d.donguEvresi}'), style: K.caption),
            ]),
          ),
        ),
        SectionLabel(s.t('cycle.thisCycle')),
        MetricRow(
          title: s.t('cycle.next'),
          subtitle: s.t('cycle.nextSub'),
          value: (uzun - gun + 1) > 0
              ? s.t2('cycle.inDays', {'n': '${uzun - gun + 1}'})
              : s.t('cycle.anyDay'),
        ),
        MetricRow(
          title: s.t('cycle.length'),
          subtitle: bas.length < 2
              ? s.t2('cycle.lengthNone', {'n': '${Dongu.varsayilanDongu}'})
              : s.t2('cycle.lengthSub', {'n': '${bas.length - 1}'}),
          value: s.t2('unit.daysN', {'n': '$uzun'}),
        ),
        MetricRow(
          title: s.t('cycle.adjust'),
          subtitle: !Ayarlar.donguDuzeltme
              ? s.t('cycle.adjustOff')
              : (fark == null
                  ? s.t('cycle.adjustWaiting')
                  : (d.donguDuzeltildi
                      ? s.t('cycle.adjustedToday')
                      : s.t('cycle.notLuteal'))),
          value: d.donguDuzeltildi ? s.t('common.yes') : s.t('common.no'),
        ),
      ],

      SectionLabel(s.t('cycle.yourShift')),
      if (fark == null && !Ayarlar.donguDuzeltme)
        NoteBlock(s.t('cycle.adjustOff'))
      else if (fark == null) ...[
        // Ne kadar veri birikti: aynı uyarıyı tekrar etmek yerine ilerleme.
        for (final r in [
          ('cycle.progressStarts', ilerleme.baslangic, 2),
          ('cycle.progressLuteal', ilerleme.luteal, Dongu.enAzGun),
          ('cycle.progressFollicular', ilerleme.folikuler, Dongu.enAzGun),
        ])
          MetricRow(
            title: s.t(r.$1),
            value: '${r.$2.clamp(0, r.$3)}/${r.$3}',
            level: r.$2 >= r.$3 ? Level.good : null,
            levelText: r.$2 >= r.$3 ? s.t('cycle.progressDone') : null,
          ),
        NoteBlock(s.t('cycle.progressNote')),
      ] else ...[
        MetricRow(
          title: s.t('today.rhr'),
          subtitle: s.t('cycle.shiftSub'),
          value: sgn(fark.rhr, digits: 1),
          unit: s.t('unit.bpm'),
        ),
        MetricRow(
          title: s.t('today.hrv'),
          subtitle: s.t('cycle.shiftSub'),
          value: '${sgn(fark.hrvYuzde, digits: 0)}%',
        ),
      ],
      if (nabiz.length > 7) ...[
        SectionLabel(s.t('cycle.rhrChart')),
        LineSeriesChart(
          values: nabiz,
          leftLabel: son56.first.label,
          rightLabel: son56.last.label,
        ),
      ],

      SectionLabel(s.t('cycle.calendar')),
      _Takvim(days: days),
      NoteBlock(s.t('cycle.calendarNote')),

      if (dongular.isNotEmpty) ...[
        SectionLabel(s.t('cycle.recent')),
        for (final c in dongular)
          MetricRow(
            title: DayRecord(c.$1).label,
            subtitle: c.$2 == null ? s.t('cycle.current') : null,
            value: c.$2 == null ? '--' : s.t2('unit.daysN', {'n': '${c.$2}'}),
          ),
      ],
      NoteBlock(s.t('cycle.note')),
    ]);
  }
}

/// Döngü bilinmiyorken: ne gerektiğini ve izin düğmesini göster.
class _BosDurum extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Kart(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t('cycle.emptyTitle'), style: K.rowTitle),
        const SizedBox(height: 4),
        Text(s.t('cycle.emptyBody'), style: K.note),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: HealthRepository.donguIzniVar(),
          builder: (context, snap) {
            if (snap.data != false) return const SizedBox.shrink();
            return Basilabilir(
              onTap: () async {
                if (await HealthRepository.donguIzniIste()) {
                  // Kayıtlar bir sonraki okumada gelsin.
                  Ayarlar.yenidenOku.value++;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: K.ink, borderRadius: BorderRadius.circular(K.kapsul)),
                child: Text(s.t('cycle.grant'),
                    style: TextStyle(
                        color: K.card, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            );
          },
        ),
      ]),
    );
  }
}

/// Son 42 günün takvimi: dokununca o gün regl olarak işaretlenir ya da
/// işaret kalkar. Health Connect'ten gelen günler ayrı gösterilir ve
/// buradan silinemez.
class _Takvim extends StatelessWidget {
  final List<DayRecord> days;
  const _Takvim({required this.days});

  static const int gunSayisi = 42;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final n = DateTime.now();
    final bugun = DateTime(n.year, n.month, n.day);
    final hc = {for (final d in days) if (d.reglHc) gunAnahtari(d.date)};
    // Haftanın ilk günü pazartesi; ızgara pazartesiyle başlasın.
    final ilk = DateTime(bugun.year, bugun.month, bugun.day - (gunSayisi - 1));
    final bosluk = (ilk.weekday - DateTime.monday) % 7;

    return ValueListenableBuilder<int>(
      valueListenable: ReglKayitlari.degisti,
      builder: (context, _, _) => Kart(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: LayoutBuilder(builder: (context, c) {
          final h = (c.maxWidth - 6 * 6) / 7;
          // Pazartesiden başlayan gün adları (o dilde, kısa).
          final gunAdlari = [
            for (var i = 0; i < 7; i++)
              DateFormat.E(S.aktifDil).format(DateTime(2024, 1, 1 + i))
          ];
          final hucreler = <Widget>[
            for (final ad in gunAdlari)
              SizedBox(
                width: h,
                child: Text(ad,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: K.axis),
              ),
            for (var i = 0; i < bosluk; i++) SizedBox(width: h, height: h),
            for (var i = 0; i < gunSayisi; i++)
              _hucre(context, s, DateTime(ilk.year, ilk.month, ilk.day + i),
                  h, hc, bugun),
          ];
          return Wrap(spacing: 6, runSpacing: 6, children: hucreler);
        }),
      ),
    );
  }

  Widget _hucre(BuildContext context, S s, DateTime g, double h,
      Set<String> hc, DateTime bugun) {
    final k = gunAnahtari(g);
    final saglik = hc.contains(k);
    final yerel = ReglKayitlari.gunler.contains(k);
    final dolu = saglik || yerel;
    final bugunMu = k == gunAnahtari(bugun);
    return Semantics(
      button: true,
      selected: dolu,
      label: '${DayRecord(g).label}${dolu ? ', ${s.t('cycle.periodDay')}' : ''}',
      child: Basilabilir(
        onTap: () {
          if (saglik) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.t('cycle.fromHc'))));
            return;
          }
          ReglKayitlari.degistir(g);
        },
        child: Container(
          width: h,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dolu ? K.badTint : K.fill,
            borderRadius: BorderRadius.circular(K.kapsul),
            border: bugunMu
                ? Border.all(color: K.ink, width: 1.5)
                : (saglik ? Border.all(color: K.badMark, width: 1) : null),
          ),
          // Ayın ilk günü ay adını da taşıyor: ızgara iki aya yayılıyor.
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (g.day == 1)
              Text(DateFormat.MMM(S.aktifDil).format(g),
                  style: TextStyle(fontSize: 9, height: 1, color: dolu ? K.bad : K.ink3)),
            Text('${g.day}',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: dolu ? FontWeight.w700 : FontWeight.w500,
                  color: dolu ? K.bad : K.ink2,
                )),
          ]),
        ),
      ),
    );
  }
}
