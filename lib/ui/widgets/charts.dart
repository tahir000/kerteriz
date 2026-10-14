import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/day_record.dart';
import '../../l10n.dart';
import '../../theme.dart';
import 'kit.dart';

class Bar {
  final double value;
  final Level? level;
  final bool highlight;
  const Bar(this.value, {this.level, this.highlight = false});
}

/// Seçili olmayan öğelerin odak sırasında ne kadar soluklaştığı.
const _soluk = 0.62;

/// Odak 0 iken tam renk; odak 1 iken seçili olmayanlar soluk.
Color _odakRengi(Color c, bool secili, double odak) =>
    secili ? c : c.withValues(alpha: c.a * (1 - _soluk * odak));

/// Dokunulan öğenin ayrıntısı. Balon [nokta]nın üstüne, yer yoksa altına
/// oturuyor.
class _Detay {
  final Offset nokta;
  final String baslik;
  final String deger;
  final Color? renk;
  const _Detay(this.nokta, this.baslik, this.deger, {this.renk});
}

/// Grafik kartlarının ortak dokunma davranışı: dokununca kart hafifçe büyür,
/// parmağın altındaki öğe seçilir ve ayrıntısı balonda görünür. Seçim
/// açıkken (ya da basılı tutunca) parmak kaydırılarak öğeler arasında
/// gezilir. Aynı öğeye yeniden dokunmak ya da birkaç saniye beklemek
/// seçimi kapatır.
///
/// Yatay sürükleme yalnızca seçim açıkken dinleniyor: yoksa grafiğin
/// üstünden sekmeler arasında kaydırmak (PageView) çalışmazdı.
class _DokunmaKarti extends StatefulWidget {
  final double height;
  final Widget Function(int? secili, double odak) cizim;
  final int? Function(Offset p, Size s) bul;
  final _Detay? Function(int i, Size s) detay;
  final Widget? ust;
  final Widget Function(int? secili, double odak)? alt;

  const _DokunmaKarti({
    required this.height,
    required this.cizim,
    required this.bul,
    required this.detay,
    this.ust,
    this.alt,
  });

  @override
  State<_DokunmaKarti> createState() => _DokunmaKartiState();
}

class _DokunmaKartiState extends State<_DokunmaKarti> {
  int? _secili;

  /// Seçim kapandıktan sonra da son öğe tutuluyor: soluklaşma geri
  /// açılırken hangi öğenin vurgulu kalacağını bilmek için.
  int? _son;
  int? _dokunmadanOnce;
  Timer? _sure;

  @override
  void dispose() {
    _sure?.cancel();
    super.dispose();
  }

  void _sec(Offset p, Size s) {
    _sure?.cancel();
    final i = widget.bul(p, s);
    if (i == null || i == _secili) return;
    HapticFeedback.selectionClick();
    setState(() => _secili = _son = i);
  }

  void _birak() {
    _sure?.cancel();
    if (_secili != null) {
      _sure = Timer(const Duration(seconds: 4), _kapat);
    }
  }

  void _kapat() {
    _sure?.cancel();
    if (mounted && _secili != null) setState(() => _secili = null);
  }

  @override
  Widget build(BuildContext context) {
    final acik = _secili != null;
    final alt = widget.alt;
    return AnimatedScale(
      scale: acik ? 1.025 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Kart(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: acik ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, odak, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.ust != null) widget.ust!,
                SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: LayoutBuilder(builder: (context, c) {
                    final size = Size(c.maxWidth, c.maxHeight);
                    final secili = _secili;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (e) {
                        _dokunmadanOnce = _secili;
                        _sec(e.localPosition, size);
                      },
                      onTapUp: (_) {
                        // Seçili öğeye yeniden dokunmak seçimi kapatıyor.
                        if (_dokunmadanOnce != null &&
                            _dokunmadanOnce == _secili) {
                          _kapat();
                        } else {
                          _birak();
                        }
                      },
                      onTapCancel: _birak,
                      onLongPressStart: (e) => _sec(e.localPosition, size),
                      onLongPressMoveUpdate: (e) =>
                          _sec(e.localPosition, size),
                      onLongPressEnd: (_) => _birak(),
                      onHorizontalDragStart: acik
                          ? (e) => _sec(e.localPosition, size)
                          : null,
                      onHorizontalDragUpdate: acik
                          ? (e) => _sec(e.localPosition, size)
                          : null,
                      onHorizontalDragEnd: acik ? (_) => _birak() : null,
                      onHorizontalDragCancel: acik ? _birak : null,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(child: widget.cizim(_son, odak)),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _BalonKatmani(
                                secili == null
                                    ? null
                                    : widget.detay(secili, size)),
                          ),
                        ),
                      ]),
                    );
                  }),
                ),
                if (alt != null) alt(_son, odak),
              ]),
        ),
      ),
    );
  }
}

/// Balonu yumuşakça gösterip gizleyen, öğeler arasında kaydıran katman.
class _BalonKatmani extends StatefulWidget {
  final _Detay? detay;
  const _BalonKatmani(this.detay);

  @override
  State<_BalonKatmani> createState() => _BalonKatmaniState();
}

class _BalonKatmaniState extends State<_BalonKatmani> {
  /// Kapanırken son içerik ekranda kalıyor; yoksa solma görünmezdi.
  _Detay? _son;

  @override
  Widget build(BuildContext context) {
    final d = widget.detay ?? _son;
    _son = d;
    if (d == null) return const SizedBox.shrink();
    final acik = widget.detay != null;
    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: d.nokta),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, n, child) =>
          CustomSingleChildLayout(delegate: _BalonYeri(n), child: child),
      child: AnimatedOpacity(
        opacity: acik ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: acik ? 1 : 0.92,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: _Balon(d),
        ),
      ),
    );
  }
}

class _BalonYeri extends SingleChildLayoutDelegate {
  final Offset n;
  const _BalonYeri(this.n);

  /// Balon kartın üst boşluğuna bu kadar taşabilir; daha yukarısı bir
  /// önceki bölümün başlığına biner.
  static const tasma = 22.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => c.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (n.dx - child.width / 2)
        .clamp(0.0, math.max(0.0, size.width - child.width))
        .toDouble();
    var y = n.dy - child.height - 7;
    if (y < -tasma) y = n.dy + 9;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _BalonYeri old) => old.n != n;
}

class _Balon extends StatelessWidget {
  final _Detay d;
  const _Balon(this.d);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: K.ink,
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (d.renk != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: d.renk, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
          ],
          Text(d.baslik,
              style: TextStyle(
                  fontSize: 11, color: K.card.withValues(alpha: 0.72))),
          const SizedBox(width: 7),
          Text(d.deger,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: K.card,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

Widget _uclar(String sol, String sag) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(sol, style: K.axis),
        Text(sag, style: K.axis),
      ]),
    );

String _sayi(double v, int decimals) => v.toStringAsFixed(decimals);

class BarSeriesChart extends StatelessWidget {
  final List<Bar> bars;
  final double height;
  final double? rule;
  final String? ruleLabel;
  final String leftLabel, rightLabel;

  /// Her sütunun adı (çoğunlukla tarih); dokununca balonda görünür.
  final List<String>? labels;

  /// Balondaki değerin biçimi. Verilmezse tam sayıya yuvarlanıyor.
  final String Function(double v)? format;

  const BarSeriesChart({
    super.key,
    required this.bars,
    this.height = 118,
    this.rule,
    this.ruleLabel,
    this.leftLabel = '',
    this.rightLabel = '',
    this.labels,
    this.format,
  });

  @override
  Widget build(BuildContext context) => _DokunmaKarti(
        height: height,
        // Sütunlar tabandan yukarı doğru büyüyerek geliyor.
        cizim: (secili, odak) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(
              painter: _BarPainter(bars, rule, ruleLabel, v, secili, odak)),
        ),
        bul: (p, s) => bars.isEmpty
            ? null
            : (p.dx / (s.width / bars.length))
                .floor()
                .clamp(0, bars.length - 1),
        detay: (i, s) {
          if (i >= bars.length) return null;
          final b = bars[i];
          final maxV = _BarPainter.olcek(bars, rule);
          final slot = s.width / bars.length;
          final h = maxV <= 0 ? 0.0 : (b.value / maxV) * s.height;
          return _Detay(
            Offset(i * slot + slot / 2, s.height - math.max(h, 1.5)),
            labels != null && i < labels!.length ? labels![i] : '${i + 1}',
            format?.call(b.value) ?? _sayi(b.value, 0),
            renk: b.highlight ? K.accent : b.level?.mark,
          );
        },
        alt: (_, _) => _uclar(leftLabel, rightLabel),
      );
}

class _BarPainter extends CustomPainter {
  final List<Bar> bars;
  final double? rule;
  final String? ruleLabel;

  /// 0 ile 1 arası giriş ilerlemesi; sütun yükseklikleri bununla çarpılıyor.
  final double ilerleme;
  final int? secili;
  final double odak;
  _BarPainter(this.bars, this.rule, this.ruleLabel,
      [this.ilerleme = 1, this.secili, this.odak = 0]);

  /// Tuvalin tepesine karşılık gelen değer; dokunma hesabı da bunu kullanıyor.
  static double olcek(List<Bar> bars, double? rule) {
    var maxV = 0.0;
    for (final b in bars) {
      if (b.value > maxV) maxV = b.value;
    }
    if (rule != null && rule > maxV) maxV = rule;
    return maxV * 1.12;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final maxV = olcek(bars, rule);
    if (maxV <= 0) return;

    final n = bars.length;
    final slot = size.width / n;
    final gap = n > 40 ? 1.0 : 2.0;
    // clamp alt sınırı üst sınırı geçerse hata fırlatır; çok dar alanda
    // slot 1 pikselin altına düşebiliyor.
    final bw = slot <= gap ? slot : slot - gap;
    final p = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final h = (b.value / maxV) * size.height * ilerleme;
      // En az 1.5 piksel çiz, ama tepeyi de o yüksekliğe göre hesapla:
      // yoksa sıfıra yakın sütunlar taban çizgisinin altına taşıyor.
      final hh = h < 1.5 ? 1.5 : h;
      final renk = b.highlight
          ? K.accent
          : (b.level?.mark ?? K.line);
      p.color = secili == null ? renk : _odakRengi(renk, i == secili, odak);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot, size.height - hh, bw, hh),
        Radius.circular(bw < 5 ? bw / 2 : 2.5),
      );
      canvas.drawRRect(r, p);
    }

    if (rule != null) {
      final y = size.height - (rule! / maxV) * size.height;
      final dash = Paint()
        ..color = K.ink
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), dash);
      }
      if (ruleLabel != null) {
        final tp = TextPainter(
          text: TextSpan(text: ruleLabel, style: K.axis),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(0, y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

class LineSeriesChart extends StatelessWidget {
  final List<double> values;
  final List<double>? bandLow, bandHigh;
  final double height;
  final Level? endLevel;
  final String leftLabel, rightLabel;
  final int decimals;

  /// Her noktanın adı (tarih ya da saat); dokununca balonda görünür.
  final List<String>? labels;

  /// Balonda değerin arkasına eklenen birim (" ms" gibi).
  final String unit;

  const LineSeriesChart({
    super.key,
    required this.values,
    this.bandLow,
    this.bandHigh,
    this.height = 130,
    this.endLevel,
    this.leftLabel = '',
    this.rightLabel = '',
    this.decimals = 0,
    this.labels,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) => _DokunmaKarti(
        height: height,
        // Çizgi soldan sağa doğru çiziliyor.
        cizim: (secili, odak) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRect(
            clipper: _SoldanSaga(v),
            child: CustomPaint(
                painter: _LinePainter(values, bandLow, bandHigh, endLevel,
                    decimals, secili, odak)),
          ),
        ),
        bul: (p, s) => values.length < 2
            ? null
            : (p.dx / s.width * (values.length - 1))
                .round()
                .clamp(0, values.length - 1),
        detay: (i, s) {
          if (i >= values.length) return null;
          final o = _LinePainter.olcek(values, bandLow, bandHigh);
          return _Detay(
            Offset(i * s.width / (values.length - 1),
                s.height * (1 - (values[i] - o.lo) / (o.hi - o.lo))),
            labels != null && i < labels!.length ? labels![i] : '${i + 1}',
            '${_sayi(values[i], decimals)}$unit',
          );
        },
        alt: (_, _) => _uclar(leftLabel, rightLabel),
      );
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? bandLow, bandHigh;
  final Level? endLevel;
  final int decimals;
  final int? secili;
  final double odak;
  _LinePainter(this.values, this.bandLow, this.bandHigh, this.endLevel,
      this.decimals, [this.secili, this.odak = 0]);

  /// Dikey eksenin alt ve üst ucu; dokunma hesabı da bunu kullanıyor.
  static ({double lo, double hi}) olcek(
      List<double> values, List<double>? bandLow, List<double>? bandHigh) {
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (bandLow != null && bandLow.isNotEmpty) {
      final bl = bandLow.reduce((a, b) => a < b ? a : b);
      if (bl < lo) lo = bl;
    }
    if (bandHigh != null && bandHigh.isNotEmpty) {
      final bh = bandHigh.reduce((a, b) => a > b ? a : b);
      if (bh > hi) hi = bh;
    }
    final pad = (hi - lo) * 0.18;
    lo -= pad == 0 ? 1 : pad;
    hi += pad == 0 ? 1 : pad;
    return (lo: lo, hi: hi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final o = olcek(values, bandLow, bandHigh);
    final lo = o.lo, hi = o.hi;

    double x(int i) => i * size.width / (values.length - 1);
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));

    final grid = Paint()
      ..color = K.line2
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final v = lo + (hi - lo) * f;
      final yy = y(v);
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(decimals), style: K.axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, yy - tp.height - 1));
    }

    if (bandLow != null &&
        bandHigh != null &&
        bandLow!.length == values.length &&
        bandHigh!.length == values.length) {
      final path = Path()..moveTo(x(0), y(bandHigh![0]));
      for (var i = 1; i < values.length; i++) {
        path.lineTo(x(i), y(bandHigh![i]));
      }
      for (var i = values.length - 1; i >= 0; i--) {
        path.lineTo(x(i), y(bandLow![i]));
      }
      path.close();
      canvas.drawPath(path, Paint()..color = K.fill);
    }

    // çizginin altına çok soluk bir alan: eğilimi okumayı kolaylaştırır
    final area = Path()..moveTo(x(0), size.height);
    for (var i = 0; i < values.length; i++) {
      area.lineTo(x(i), y(values[i]));
    }
    area.lineTo(x(values.length - 1), size.height);
    area.close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (endLevel?.mark ?? K.ink).withValues(alpha: 0.10),
              (endLevel?.mark ?? K.ink).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Seçili noktanın dikey kılavuzu: çizginin altında kalsın.
    final s = secili;
    if (s != null && s < values.length && odak > 0) {
      final sx = x(s);
      final kilavuz = Paint()
        ..color = K.ink3.withValues(alpha: 0.55 * odak)
        ..strokeWidth = 1;
      for (var yy = 0.0; yy < size.height; yy += 5) {
        canvas.drawLine(Offset(sx, yy), Offset(sx, yy + 2.5), kilavuz);
      }
    }

    final line = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = K.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);

    final last = Offset(x(values.length - 1), y(values.last));
    // Uç noktanın halesi kart zemini: koyu temada beyaz bir benek kalırdı.
    canvas.drawCircle(last, 5, Paint()..color = K.card);
    canvas.drawCircle(last, 4.2, Paint()..color = endLevel?.mark ?? K.accent);

    if (s != null && s < values.length && odak > 0) {
      final nokta = Offset(x(s), y(values[s]));
      canvas.drawCircle(
          nokta, 6.5 * odak, Paint()..color = K.card.withValues(alpha: odak));
      canvas.drawCircle(nokta, 4.6 * odak,
          Paint()..color = K.ink.withValues(alpha: odak));
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Gecenin evre serisi — dört satır, her segment bir çubuk.
class Hypnogram extends StatelessWidget {
  final DayRecord day;
  final Map<String, String> names;
  const Hypnogram(this.day, {super.key, required this.names});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final segs = day.segments;
    return _DokunmaKarti(
      height: 104,
      cizim: (secili, odak) =>
          CustomPaint(painter: _HypnoPainter(day, names, secili, odak)),
      bul: (p, size) {
        if (day.bedStart == null || day.timeInBed <= 0) return null;
        final t = day.bedStart!.add(Duration(
            minutes: ((p.dx - _HypnoPainter.gutter) /
                    (size.width - _HypnoPainter.gutter) *
                    day.timeInBed)
                .round()));
        // Parmağın altındaki segment; arada boşluk varsa en yakını.
        int? enYakin;
        var fark = double.infinity;
        for (var i = 0; i < segs.length; i++) {
          final g = segs[i];
          if (!_HypnoPainter.rows.containsKey(g.stage)) continue;
          if (!t.isBefore(g.start) && t.isBefore(g.end)) return i;
          final f = math.min(
            g.start.difference(t).inSeconds.abs(),
            g.end.difference(t).inSeconds.abs(),
          ).toDouble();
          if (f < fark) {
            fark = f;
            enYakin = i;
          }
        }
        return enYakin;
      },
      detay: (i, size) {
        if (i >= segs.length || day.bedStart == null) return null;
        final g = segs[i];
        final row = _HypnoPainter.rows[g.stage]!;
        final plot = size.width - _HypnoPainter.gutter;
        final t0 = g.start.difference(day.bedStart!).inMinutes / day.timeInBed;
        final w = g.minutes / day.timeInBed * plot;
        return _Detay(
          Offset(_HypnoPainter.gutter + t0 * plot + w / 2,
              row * (_HypnoPainter.rh + _HypnoPainter.gap)),
          names[g.stage] ?? g.stage,
          '${fmtClock(g.start)}–${fmtClock(g.end)} · '
              '${fmtDur(g.minutes, h: s.t('common.hourShort'), m: s.t('common.minShort'))}',
          renk: _HypnoPainter.colors[row],
        );
      },
      alt: (_, _) => _uclar(fmtClock(day.bedStart), fmtClock(day.wakeEnd)),
    );
  }
}

class _HypnoPainter extends CustomPainter {
  final DayRecord d;
  final Map<String, String> names;
  final int? secili;
  final double odak;
  _HypnoPainter(this.d, this.names, [this.secili, this.odak = 0]);

  static const rows = {'awake': 0, 'rem': 1, 'light': 2, 'deep': 3};
  static const order = ['awake', 'rem', 'light', 'deep'];
  static const gutter = 46.0, rh = 20.0, gap = 6.0;
  static List<Color> get colors =>
      [K.stageWake, K.stageRem, K.stageLight, K.stageDeep];

  @override
  void paint(Canvas canvas, Size size) {
    if (d.bedStart == null || d.timeInBed <= 0) return;
    final plot = size.width - gutter;

    for (var i = 0; i < order.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: names[order[i]] ?? order[i], style: K.axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, i * (rh + gap) + 2));
    }

    final renkler = colors;
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < d.segments.length; i++) {
      final s = d.segments[i];
      final row = rows[s.stage];
      if (row == null) continue;
      final t0 = s.start.difference(d.bedStart!).inMinutes / d.timeInBed;
      final w = (s.minutes / d.timeInBed) * plot;
      p.color = secili == null
          ? renkler[row]
          : _odakRengi(renkler[row], i == secili, odak);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(gutter + t0 * plot, row * (rh + gap), w < 1.4 ? 1.4 : w, rh - 6),
          const Radius.circular(2),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HypnoPainter old) => true;
}

class StackBar extends StatelessWidget {
  final List<MapEntry<Color, double>> parts;

  /// Parçaların adları; dokununca alttaki satırda süre ve payla birlikte
  /// görünüyor. Parça değerleri dakika.
  final List<String>? names;
  const StackBar(this.parts, {super.key, this.names});

  static const _ara = 2.0;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();
    final s = S.of(context);
    final flex = [
      for (final e in parts) (e.value / total * 1000).round().clamp(1, 1000)
    ];
    final flexTop = flex.fold<int>(0, (a, b) => a + b);
    return _DokunmaKarti(
      height: 16,
      cizim: (secili, odak) => Row(
        children: [
          for (var i = 0; i < parts.length; i++)
            Expanded(
              flex: flex[i],
              child: Container(
                height: 16,
                margin: const EdgeInsets.only(right: _ara),
                decoration: BoxDecoration(
                    color: secili == null
                        ? parts[i].key
                        : _odakRengi(parts[i].key, i == secili, odak),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
      bul: (p, size) {
        // Expanded paylaşımıyla aynı hesap: boşluklar parçaların içinde.
        var x = 0.0;
        for (var i = 0; i < parts.length; i++) {
          x += flex[i] / flexTop * size.width;
          if (p.dx < x) return i;
        }
        return parts.length - 1;
      },
      // Şerit balon sığmayacak kadar ince: ayrıntı alttaki satırda.
      detay: (_, _) => null,
      alt: (secili, odak) {
        final i = secili != null && secili < parts.length ? secili : null;
        final satir = i == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: parts[i].key,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 7),
                  if (names != null && i < names!.length) ...[
                    Text(names![i],
                        style: TextStyle(fontSize: 12.5, color: K.ink2)),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    fmtDur(parts[i].value,
                        h: s.t('common.hourShort'), m: s.t('common.minShort')),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: K.ink),
                  ),
                  const Spacer(),
                  Text('%${(parts[i].value / total * 100).round()}',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: K.ink3,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              );
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: odak,
            child: Opacity(opacity: odak, child: satir),
          ),
        );
      },
    );
  }
}

/// Uyku penceresi haritası: her satır bir gece, bant uykuda geçen süre.
class SleepRaster extends StatelessWidget {
  final List<DayRecord> days;
  const SleepRaster(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const satir = _RasterPainter.rh + _RasterPainter.gap;
    return _DokunmaKarti(
      height: days.length * satir + 4,
      ust: days.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  s.t2('sleep.rasterRange',
                      {'a': days.first.label, 'b': days.last.label}),
                  style: K.axis),
            ),
      // Kırpıcı bir güvenlik ağı: bant hesabı tuvalin dışına taşsa bile
      // boya kartın kenarını aşmıyor.
      cizim: (secili, odak) =>
          ClipRect(child: CustomPaint(painter: _RasterPainter(days, secili, odak))),
      bul: (p, size) => days.isEmpty
          ? null
          : (p.dy / satir).floor().clamp(0, days.length - 1),
      detay: (i, size) {
        if (i >= days.length) return null;
        final d = days[i];
        final bant = _RasterPainter.bant(d, size.width);
        return _Detay(
          Offset(bant == null ? size.width / 2 : bant.$1 + bant.$2 / 2,
              i * satir),
          d.label,
          bant == null
              ? '--'
              : '${fmtClock(d.bedStart)}–${fmtClock(d.wakeEnd)} · '
                  '${fmtDur(d.asleep, h: s.t('common.hourShort'), m: s.t('common.minShort'))}',
          renk: bant == null ? null : Levels.score(d.sleepScore).mark,
        );
      },
      // Dört saatte bir: tuvaldeki dikey çizgilerle aynı yerde.
      alt: (_, _) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final t in const ['20:00', '00:00', '04:00', '08:00', '12:00'])
            Text(t, style: K.axis),
        ]),
      ),
    );
  }
}

class _RasterPainter extends CustomPainter {
  final List<DayRecord> days;
  final int? secili;
  final double odak;
  _RasterPainter(this.days, [this.secili, this.odak = 0]);

  static const rh = 6.0, gap = 1.6, span = 960.0; // 20:00 -> 12:00

  /// Gecenin bandı (x, genişlik); yatış bilinmiyorsa null.
  static (double, double)? bant(DayRecord d, double width) {
    final b = d.bedOffset;
    if (b == null || d.timeInBed <= 0) return null;
    // x ve w'yi ayrı ayrı kırpmak yetmiyor: ikisi de tek tek sınırda kalsa
    // bile toplamı tuvali aşabiliyor (geç yatıp uzun uyunan geceler).
    // Bandı önce sola, sonra kalan genişliğe göre sağa sığdırıyoruz.
    final x = (b / span).clamp(0.0, 1.0) * width;
    var w = (d.timeInBed / span).clamp(0.0, 1.0) * width;
    if (w < 1) w = 1;
    if (x + w > width) w = width - x;
    if (w <= 0) return null;
    return (x, w);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final y = i * (rh + gap);
      Color renk(Color c) =>
          secili == null ? c : _odakRengi(c, i == secili, odak);
      p.color = renk(K.line2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, y, size.width, rh), const Radius.circular(1)),
        p,
      );
      final b = bant(d, size.width);
      if (b == null) continue;
      p.color = renk(Levels.score(d.sleepScore).mark);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(b.$1, y, b.$2, rh), const Radius.circular(1)),
        p,
      );
    }
    // Saat çizgileri (00:00, 04:00, 08:00): bantların hangi saatte
    // başladığı gözle okunabilsin.
    final cizgi = Paint()
      ..color = K.ink3.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    final h = days.length * (rh + gap);
    for (var dk = 240.0; dk < span; dk += 240) {
      final x = dk / span * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, h), cizgi);
    }
  }

  @override
  bool shouldRepaint(covariant _RasterPainter old) => true;
}


/// Soldan sağa açılan kırpıcı: çizgi grafiğinin çizilerek gelmesi için.
class _SoldanSaga extends CustomClipper<Rect> {
  final double ilerleme;
  const _SoldanSaga(this.ilerleme);

  // Yalnızca sağ kenarı hareket ediyor. Öteki kenarlar cömert: _LinePainter
  // üst etiketi tuvalin dışına, uç noktayı da sağ kenarın üstüne çiziyor;
  // dar bir kırpma onları kesiyordu.
  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        -4,
        -26,
        size.width * ilerleme.clamp(0.0, 1.0) + 8,
        size.height + 4,
      );

  @override
  bool shouldReclip(covariant _SoldanSaga old) => old.ilerleme != ilerleme;
}
