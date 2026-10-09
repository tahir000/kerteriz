import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../theme.dart';
import '../ayarlar_ekrani.dart';
import 'gauge.dart';

/// Gri zemin üstünde duran beyaz kart. MagicOS'un baskın yüzey birimi.
class Kart extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const Kart({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 15, 16, 15),
    this.margin = const EdgeInsets.fromLTRB(K.gutter, 4, K.gutter, 4),
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: K.kartDekor,
        child: child,
      );
}

/// Dokunulduğunda hafifçe küçülen sarmalayıcı. Dalga efekti yerine ölçek
/// kullanıyoruz: beyaz kartta dalga kirli görünüyor, ölçek temiz.
class Basilabilir extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const Basilabilir({super.key, required this.child, required this.onTap});

  @override
  State<Basilabilir> createState() => _BasilabilirState();
}

class _BasilabilirState extends State<Basilabilir> {
  bool _basili = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _basili = true),
        onTapCancel: () => setState(() => _basili = false),
        onTapUp: (_) => setState(() => _basili = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _basili ? 0.975 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(buyukHarf(text), style: K.eyebrow);
}

class ScreenHead extends StatelessWidget {
  final String eyebrow;
  final String title;

  /// Başlığın sağındaki ayar düğmesi. Ayarlar ekranının kendi başlığında
  /// kapatılıyor: oradan yine ayarlara gitmenin anlamı yok.
  final bool ayarlar;

  const ScreenHead(this.eyebrow, this.title, {super.key, this.ayarlar = true});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 24, K.gutter, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 5),
              Text(title, style: K.title),
            ]),
          ),
          if (ayarlar) ...[
            const SizedBox(width: 10),
            const AyarDugmesi(),
          ],
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.fromLTRB(K.gutter + 4, K.sectionGap, K.gutter, 8),
        child: Eyebrow(text),
      );
}

class StatusChip extends StatelessWidget {
  final Level level;
  final String text;
  const StatusChip(this.level, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: level.tint, borderRadius: BorderRadius.circular(K.kapsul)),
        child: Text(buyukHarf(text),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: level.ink)),
      );
}

/// Üç bölgeli ölçek: kırmızı / turuncu / yeşil zemin, siyah iğne.
class ZoneMeter extends StatelessWidget {
  final double value, min, max;
  final List<MapEntry<double, Level>> zones; // üst sınır -> seviye
  final String leftLabel, rightLabel;

  const ZoneMeter({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.zones,
    required this.leftLabel,
    required this.rightLabel,
  });

  factory ZoneMeter.zScore(double v) => ZoneMeter(
        value: v,
        min: -2.5,
        max: 2.5,
        zones: const [
          MapEntry(-1.5, Level.bad),
          MapEntry(-0.5, Level.warn),
          MapEntry(2.5, Level.good),
        ],
        leftLabel: '-2.5 z',
        rightLabel: '+2.5 z',
      );

  factory ZoneMeter.score(double v) => ZoneMeter(
        value: v,
        min: 0,
        max: 100,
        zones: const [
          MapEntry(60, Level.bad),
          MapEntry(80, Level.warn),
          MapEntry(100, Level.good),
        ],
        leftLabel: '0',
        rightLabel: '100',
      );

  /// Su ölçeği: 0 -> hedefin 1.4 katı. Hedefin %70'i altı kırmızı.
  factory ZoneMeter.water(double v, double goal) {
    // Hedef sıfır ya da negatif girilirse ölçek NaN üretir; güvenli tabana çek.
    final g = goal > 0 ? goal : 1.0;
    return ZoneMeter(
      value: v,
      min: 0,
      max: g * 1.4,
      zones: [
        MapEntry(g * 0.7, Level.bad),
        MapEntry(g, Level.warn),
        MapEntry(g * 1.4, Level.good),
      ],
      leftLabel: '0',
      rightLabel: '${(g * 1.4).round()} ml',
    );
  }

  factory ZoneMeter.acwr(double v) => ZoneMeter(
        value: v,
        min: 0.4,
        max: 1.8,
        zones: const [
          MapEntry(0.6, Level.bad),
          MapEntry(0.8, Level.warn),
          MapEntry(1.3, Level.good),
          MapEntry(1.5, Level.warn),
          MapEntry(1.8, Level.bad),
        ],
        leftLabel: '0.40',
        rightLabel: '1.80',
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          // num.clamp alt sinir ust siniri gecerse hata firlatir; olcek
          // cizilemeyecek kadar darsa hic cizme.
          if (w < 3) return const SizedBox(height: 13);
          double p(double x) => ((x - min) / (max - min)).clamp(0.0, 1.0) * w;
          final bars = <Widget>[];
          var prev = min;
          for (final z in zones) {
            final a = p(prev), b = p(z.key);
            bars.add(Positioned(
              left: a,
              width: (b - a).clamp(0.0, w),
              top: 0,
              bottom: 0,
              child: Container(color: z.value.mark),
            ));
            prev = z.key;
          }
          return SizedBox(
            height: 13,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(K.kapsul),
                  child: SizedBox(
                      height: 5,
                      child: Stack(children: [
                        Container(color: K.line2),
                        ...bars,
                      ])),
                ),
              ),
              Positioned(
                left: (p(value) - 1.5).clamp(0.0, w - 3),
                top: 0,
                child: Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                      color: K.ink,
                      borderRadius: BorderRadius.circular(2),
                      // Çerçeve kart zemininde: iki temada da işaretçiyi
                      // altındaki bantlardan ayırıyor.
                      border: Border.all(color: K.card, width: 1.2)),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(leftLabel, style: K.axis),
          Text(rightLabel, style: K.axis),
        ]),
      ]),
    );
  }
}

class MetricRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final String? unit;
  final Level? level;
  final String? levelText;
  final Widget? extra;
  final VoidCallback? onTap;
  final List<double>? trend;

  const MetricRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.unit,
    this.level,
    this.levelText,
    this.extra,
    this.onTap,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final sub = <Widget>[];
    if (level != null && levelText != null) {
      sub.add(StatusChip(level!, levelText!));
    }
    if (subtitle != null) {
      // Wrap içinde Flexible kullanılamaz; Wrap zaten genişliği kısıtlıyor.
      sub.add(Text(subtitle!, style: K.rowSub));
    }

    final content = Container(
      margin: const EdgeInsets.fromLTRB(K.gutter, 3, K.gutter, 3),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: K.kartDekor,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: K.rowTitle),
            if (sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center, children: sub),
              ),
            ?extra,
          ]),
        ),
        if (trend != null && trend!.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Sparkline(trend!, color: level?.mark ?? K.ink4),
          ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: RichText(
              text: TextSpan(
                text: value,
                style: K.rowValue.copyWith(color: level?.ink ?? K.ink),
                children: [
                  if (unit != null)
                    TextSpan(
                        text: unit,
                        style: TextStyle(fontSize: 12, color: K.ink3)),
                ],
              ),
            ),
          ),
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.chevron_right, size: 18, color: K.ink3),
          ),
      ]),
    );

    if (onTap == null) return content;
    return Basilabilir(onTap: onTap!, child: content);
  }
}

class NoteBlock extends StatelessWidget {
  final String text;
  const NoteBlock(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(K.gutter, 10, K.gutter, 4),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(K.rKart),
          boxShadow: K.golge,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
                color: K.line, borderRadius: BorderRadius.circular(K.rIc)),
          ),
          Expanded(child: Text(text, style: K.note)),
        ]),
      );
}

class LevelScale extends StatelessWidget {
  const LevelScale({super.key});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter + 4, 10, K.gutter, 0),
        child: Wrap(spacing: 14, runSpacing: 6, children: [
          for (final e in [
            MapEntry(Level.good, s.t('lvl.good')),
            MapEntry(Level.warn, s.t('lvl.watch')),
            MapEntry(Level.bad, s.t('lvl.low')),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: e.key.mark,
                      borderRadius: BorderRadius.circular(K.kapsul))),
              const SizedBox(width: 5),
              Text(e.value, style: TextStyle(fontSize: 11, color: K.ink2)),
            ]),
        ]));
  }
}

/// Bölmeli seçici: kapsül bir hattın içinde kayan bir gösterge.
///
/// Seçenek sayısı azken (iki ya da üç) açılır menüden daha okunur:
/// bütün seçenekler aynı anda görünüyor, seçili olan da hareketle
/// belli oluyor. Gösterge [AnimatedAlign] ile kayıyor.
class SegmentliSecici extends StatelessWidget {
  final List<String> etiketler;
  final int secili;
  final ValueChanged<int> onChanged;

  const SegmentliSecici({
    super.key,
    required this.etiketler,
    required this.secili,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final n = etiketler.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(K.gutter, 4, K.gutter, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: K.fill,
        borderRadius: BorderRadius.circular(K.rDugme),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth) / n;
          return SizedBox(
            height: 38,
            child: Stack(children: [
              // Kayan gösterge. Hizalama -1..1 aralığında olduğu için
              // bölme ortalarını o aralığa eşliyoruz.
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                // Tek seçenek varsa bölme tam ortada; yoksa seçili bölmenin
                // ortası -1..1 hizalama aralığına taşınıyor.
                alignment: Alignment(
                    n == 1 ? 0.0 : (secili / (n - 1)) * 2 - 1, 0),
                child: Container(
                  width: w,
                  height: 38,
                  decoration: BoxDecoration(
                    color: K.card,
                    borderRadius: BorderRadius.circular(K.rDugme - 3),
                    boxShadow: K.cubukGolge,
                  ),
                ),
              ),
              Row(children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 240),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                i == secili ? FontWeight.w600 : FontWeight.w500,
                            color: i == secili ? K.ink : K.ink2,
                          ),
                          child: Text(etiketler[i]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

/// Ayarlardaki sayı satırı: eksi ve artı düğmeleriyle değiştirilen bir değer.
///
/// Klavye yerine düğme: yaş ve hedefler tek elle, yanlış yazma ihtimali
/// olmadan ayarlanıyor. Sınırlar [Ayarlar] tarafında da uygulanıyor, buradaki
/// [enAz] / [enCok] yalnızca düğmeyi soluklaştırmak için.
class SayiSatiri extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int deger;
  final int adim;
  final int enAz;
  final int enCok;
  final String? birim;

  /// Ekranda gösterilecek biçim. Verilmezse sayının kendisi yazılır
  /// (mesafe hedefi onda bir kilometre tutulduğu için gerekiyor).
  final String Function(int)? bicim;
  final ValueChanged<int> onChanged;

  const SayiSatiri({
    super.key,
    required this.title,
    required this.deger,
    required this.adim,
    required this.enAz,
    required this.enCok,
    required this.onChanged,
    this.subtitle,
    this.birim,
    this.bicim,
  });

  Widget _dugme(IconData ikon, bool acik, VoidCallback onTap) => Opacity(
        opacity: acik ? 1 : 0.35,
        child: Basilabilir(
          onTap: acik ? onTap : () {},
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: K.fill,
              borderRadius: BorderRadius.circular(K.kapsul),
            ),
            child: Icon(ikon, size: 18, color: K.ink),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Kart(
        padding: const EdgeInsets.fromLTRB(16, 13, 13, 13),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: K.rowTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: K.rowSub),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          _dugme(Icons.remove, deger > enAz,
              () => onChanged((deger - adim) < enAz ? enAz : deger - adim)),
          SizedBox(
            width: 78,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Rakam bölünemiyor: sistem yazı ölçeği büyükken beş haneli
              // hedef sütunu taşırırdı. Küçülterek sığdırıyoruz.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(bicim?.call(deger) ?? '$deger',
                    style: K.rowValue, textAlign: TextAlign.center),
              ),
              if (birim != null)
                // Birim jetonları satır içi kullanım için baştan boşluklu
                // ('  ml'); burada alt satırda ortalandığı için kırpılıyor.
                Text(birim!.trim(), style: K.axis, textAlign: TextAlign.center),
            ]),
          ),
          _dugme(Icons.add, deger < enCok,
              () => onChanged((deger + adim) > enCok ? enCok : deger + adim)),
        ]),
      );
}

/// Açılıp kapanan kapsül. Etiket günlüğünde kullanılıyor; seçili durum
/// yalnızca renkle değil, onay işaretiyle de belli.
class SecimCipi extends StatelessWidget {
  final String text;
  final bool secili;
  final VoidCallback onTap;

  const SecimCipi(this.text,
      {super.key, required this.secili, required this.onTap});

  @override
  Widget build(BuildContext context) => Basilabilir(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: secili ? K.ink : K.fill,
            borderRadius: BorderRadius.circular(K.kapsul),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (secili) ...[
              Icon(Icons.check, size: 15, color: K.card),
              const SizedBox(width: 5),
            ],
            Text(text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: secili ? K.card : K.ink2,
                )),
          ]),
        ),
      );
}

/// Açılıp kapanan bölüm. Başlık [SectionLabel] ile aynı yerde; sağında
/// kapalıyken görünen kısa bir özet ve ok var.
///
/// Açık/kapalı durumu [anahtar] ile oturum boyunca hatırlanıyor: veri
/// tazelendiğinde ekran yeniden kuruluyor ve kullanıcının açtığı bölüm
/// kendiliğinden kapanmamalı.
class Acilir extends StatefulWidget {
  final String anahtar;
  final String baslik;
  final String? ozet;
  final bool baslangictaAcik;
  final List<Widget> children;

  const Acilir({
    super.key,
    required this.anahtar,
    required this.baslik,
    required this.children,
    this.ozet,
    this.baslangictaAcik = false,
  });

  static final Map<String, bool> _durum = {};

  @override
  State<Acilir> createState() => _AcilirState();
}

class _AcilirState extends State<Acilir> {
  bool get _acik => Acilir._durum[widget.anahtar] ?? widget.baslangictaAcik;

  @override
  Widget build(BuildContext context) {
    final acik = _acik;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        expanded: acik,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => Acilir._durum[widget.anahtar] = !acik),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                K.gutter + 4, K.sectionGap, K.gutter, 8),
            child: Row(children: [
              Expanded(child: Eyebrow(widget.baslik)),
              if (!acik && widget.ozet != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(widget.ozet!, style: K.rowSub),
                ),
              AnimatedRotation(
                turns: acik ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, size: 20, color: K.ink3),
              ),
            ]),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: acik
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children)
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}

/// İki grubun karşılaştırması: iki yatay çubuk, gün sayıları ve fark.
/// Renk yön bildirmiyor; hangisinin "iyi" olduğu metinde yazıyor.
class KarsilastirmaKarti extends StatelessWidget {
  final String baslik;
  final String? aciklama;
  final String etiketA;
  final double degerA;
  final int nA;
  final String etiketB;
  final double degerB;
  final int nB;
  final String Function(double) bicim;
  final String sonucMetni;

  const KarsilastirmaKarti({
    super.key,
    required this.baslik,
    required this.etiketA,
    required this.degerA,
    required this.nA,
    required this.etiketB,
    required this.degerB,
    required this.nB,
    required this.bicim,
    required this.sonucMetni,
    this.aciklama,
  });

  Widget _cubuk(String etiket, double deger, int n, double enCok, bool vurgu,
          String gunBirimi) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(etiket, style: K.rowSub)),
            Text(bicim(deger),
                style: K.rowValue.copyWith(fontSize: 16, color: K.ink)),
          ]),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, c) => Stack(children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                    color: K.fill, borderRadius: BorderRadius.circular(K.kapsul)),
              ),
              Container(
                width: enCok <= 0
                    ? 0
                    : (c.maxWidth * (deger.abs() / enCok)).clamp(4.0, c.maxWidth),
                height: 8,
                decoration: BoxDecoration(
                    color: vurgu ? K.ink : K.ink4,
                    borderRadius: BorderRadius.circular(K.kapsul)),
              ),
            ]),
          ),
          const SizedBox(height: 3),
          Text('$n$gunBirimi', style: K.axis),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final enCok = [degerA.abs(), degerB.abs()].reduce((a, b) => a > b ? a : b);
    return Kart(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik, style: K.rowTitle),
        if (aciklama != null) ...[
          const SizedBox(height: 2),
          Text(aciklama!, style: K.rowSub),
        ],
        _cubuk(etiketA, degerA, nA, enCok, true, s.t('unit.day')),
        _cubuk(etiketB, degerB, nB, enCok, false, s.t('unit.day')),
        const SizedBox(height: 12),
        Text(sonucMetni, style: K.note),
      ]),
    );
  }
}
