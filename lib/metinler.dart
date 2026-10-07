import 'l10n.dart';
import 'metrics/insights.dart';
import 'theme.dart';

/// Günün cümlesinin metni. Bugün ekranı ve ana ekran widget'ları (özet
/// dosyası üzerinden) aynı cümleyi göstersin diye tek yerde.
String gununCumlesiMetni(S s, Headline h) {
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
