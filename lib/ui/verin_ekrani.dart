import 'package:flutter/material.dart';

import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../data/etiketler.dart';
import '../data/hisler.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../metrics/insights.dart';
import '../theme.dart';
import 'widgets/kit.dart';

/// "Senin verin ne diyor": kullanıcının kendi verisinden çıkan
/// karşılaştırmalar tek yerde.
///
/// Uygulamanın Fitbit'in kendi skorlarından ayrıştığı yer burası. Skor
/// vermek yerine "alkol senin ertesi sabahını ne kadar etkiliyor" sorusuna
/// kendi gecelerinle cevap veriyor. İlke su karşılaştırmasıyla aynı:
/// katsayı uydurulmaz, her iki grupta en az dört gün, ve bunun ilişki
/// olduğu, neden olmadığı açıkça yazılır.
class VerinEkrani extends StatelessWidget {
  /// Filtrelenmiş liste (uyku ya da nabız olan günler).
  final List<DayRecord> days;

  /// Filtrelenmemiş liste: su ve etiketler "ertesi gün" ilişkisine bakıyor.
  final List<DayRecord> allDays;

  const VerinEkrani({super.key, required this.days, required this.allDays});

  /// Kaç karşılaştırma gösterilebilecek kadar veriye sahip. Bugün ekranındaki
  /// giriş satırı bunu yazıyor.
  static int hazirSayisi(List<DayRecord> days, List<DayRecord> allDays) =>
      Insights.tagEffects(allDays, Etiketler.kayit).length +
      (MetricsEngine.hydrationEffect(allDays, Ayarlar.suHedefiMl) == null
          ? 0
          : 1) +
      Deneyler.otomatik(days).length +
      (Deneyler.hisVeSkor(days, Hisler.kayit) == null ? 0 : 1);

  String _dur(S s, num m) =>
      fmtDur(m, h: s.t('common.hourShort'), m: s.t('common.minShort'));

  Widget _otomatik(S s, Comparison c) {
    String sayi(double v) => v.toStringAsFixed(0);
    switch (c.key) {
      case 'erkenYatis':
        // Eşik 20:00'dan itibaren dakika; saate çeviriyoruz.
        final saat = saatDakika((20 * 60 + c.esik).round());
        return KarsilastirmaKarti(
          baslik: s.t('insights.erkenYatis.title'),
          aciklama: s.t2('insights.erkenYatis.sub', {'saat': saat}),
          etiketA: s.t2('insights.erkenYatis.a', {'saat': saat}),
          degerA: c.a,
          nA: c.nA,
          etiketB: s.t2('insights.erkenYatis.b', {'saat': saat}),
          degerB: c.b,
          nB: c.nB,
          bicim: sayi,
          sonucMetni: s.t2('insights.erkenYatis.result',
              {'delta': sgn(c.delta, digits: 0)}),
        );
      case 'yukluGun':
        return KarsilastirmaKarti(
          baslik: s.t('insights.yukluGun.title'),
          aciklama: s.t('insights.yukluGun.sub'),
          etiketA: s.t2('insights.yukluGun.a', {'esik': c.esik.toStringAsFixed(1)}),
          degerA: c.a,
          nA: c.nA,
          etiketB: s.t2('insights.yukluGun.b', {'esik': c.esik.toStringAsFixed(1)}),
          degerB: c.b,
          nB: c.nB,
          bicim: (v) => '${sgn(v, digits: 1)} z',
          sonucMetni: s.t2('insights.yukluGun.result',
              {'delta': sgn(c.delta, digits: 1)}),
        );
      case 'adim':
        final esik = c.esik.round().toString();
        return KarsilastirmaKarti(
          baslik: s.t('insights.adim.title'),
          aciklama: s.t('insights.adim.sub'),
          etiketA: s.t2('insights.adim.a', {'esik': esik}),
          degerA: c.a,
          nA: c.nA,
          etiketB: s.t2('insights.adim.b', {'esik': esik}),
          degerB: c.b,
          nB: c.nB,
          bicim: sayi,
          sonucMetni: s.t2('insights.adim.result',
              {'delta': sgn(c.delta, digits: 0)}),
        );
      default: // sekerleme
        return KarsilastirmaKarti(
          baslik: s.t('insights.sekerleme.title'),
          aciklama: s.t('insights.sekerleme.sub'),
          etiketA: s.t('insights.sekerleme.a'),
          degerA: c.a,
          nA: c.nA,
          etiketB: s.t('insights.sekerleme.b'),
          degerB: c.b,
          nB: c.nB,
          bicim: (v) => _dur(s, v),
          sonucMetni: s.t2('insights.sekerleme.result', {
            'delta': (c.delta >= 0 ? '+' : '−') + _dur(s, c.delta.abs()),
          }),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final otomatik = Deneyler.otomatik(days);
    final su = MetricsEngine.hydrationEffect(allDays, Ayarlar.suHedefiMl);

    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<int>(
          valueListenable: Etiketler.degisti,
          builder: (context, _, _) {
            final etiketler = Insights.tagEffects(allDays, Etiketler.kayit);
            return ListView(
                padding: const EdgeInsets.only(bottom: 44),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(K.gutter - 6, 8, K.gutter, 0),
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
                  ScreenHead(s.t('app.name'), s.t('insights.title'),
                      ayarlar: false),
                  NoteBlock(s.t('insights.intro')),

                  // ---- his ve skor ----
                  SectionLabel(s.t('feel.section')),
                  ValueListenableBuilder<int>(
                    valueListenable: Hisler.degisti,
                    builder: (context, _, _) {
                      final c = Deneyler.hisVeSkor(days, Hisler.kayit);
                      if (c == null) {
                        return NoteBlock(s.t2('feel.waiting',
                            {'n': '${Hisler.kayit.length}'}));
                      }
                      return KarsilastirmaKarti(
                        baslik: s.t('feel.compareTitle'),
                        aciklama: s.t('feel.compareSub'),
                        etiketA: s.t('feel.good'),
                        degerA: c.a,
                        nA: c.nA,
                        etiketB: s.t('feel.bad'),
                        degerB: c.b,
                        nB: c.nB,
                        bicim: (v) => v.toStringAsFixed(0),
                        sonucMetni: s.t2(
                            c.delta >= 10
                                ? 'feel.resultMatch'
                                : (c.delta > 0
                                    ? 'feel.resultWeak'
                                    : 'feel.resultNone'),
                            {'delta': sgn(c.delta, digits: 0)}),
                      );
                    },
                  ),

                  // ---- etiketler ----
                  SectionLabel(s.t('insights.tags')),
                  if (etiketler.isEmpty)
                    NoteBlock(s.t2('tags.waiting',
                        {'n': '${Etiketler.kayit.length}'}))
                  else
                    for (final e in etiketler)
                      KarsilastirmaKarti(
                        baslik: s.t('tag.${e.tag}'),
                        aciklama: s.t('insights.tagSub'),
                        etiketA: s.t('insights.tagWith'),
                        degerA: e.withReadiness,
                        nA: e.withDays,
                        etiketB: s.t('insights.tagWithout'),
                        degerB: e.withoutReadiness,
                        nB: e.withoutDays,
                        bicim: (v) => v.toStringAsFixed(0),
                        sonucMetni: s.t2('insights.tagResult',
                            {'delta': sgn(e.delta, digits: 0)}),
                      ),

                  // ---- su ----
                  SectionLabel(s.t('today.water')),
                  if (su == null)
                    NoteBlock(s.t('today.waterLinkNone'))
                  else
                    KarsilastirmaKarti(
                      baslik: s.t('insights.water.title'),
                      aciklama: s.t2('insights.water.sub',
                          {'goal': '${Ayarlar.suHedefiMl}'}),
                      etiketA: s.t('insights.water.a'),
                      degerA: su.atReadiness,
                      nA: su.atDays,
                      etiketB: s.t('insights.water.b'),
                      degerB: su.belowReadiness,
                      nB: su.belowDays,
                      bicim: (v) => v.toStringAsFixed(0),
                      sonucMetni: s.t2('insights.tagResult',
                          {'delta': sgn(su.delta, digits: 0)}),
                    ),
                  NoteBlock(s.t('today.waterNote')),

                  // ---- kendiliğinden ----
                  SectionLabel(s.t('insights.auto')),
                  if (otomatik.isEmpty)
                    NoteBlock(s.t('insights.autoNone'))
                  else
                    for (final c in otomatik) _otomatik(s, c),
                  NoteBlock(s.t('insights.caveat')),
                ]);
          },
        ),
      ),
    );
  }
}
