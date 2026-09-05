import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Hero degerler icin yay gostergesi.
///
/// 260 derecelik bir yay: soluk bir iz uzerine seviye renginde dolan bir kavis,
/// ortasinda sayinin kendisi. Renk tek basina anlam tasimiyor — sayi da,
/// altindaki etiket de orada.
class ArcGauge extends StatelessWidget {
  final double value; // 0..max
  final double max;
  final Level level;
  final String display; // ortada yazan
  final String? unit;
  final String? label; // yayin altindaki kucuk etiket
  final double size;

  const ArcGauge({
    super.key,
    required this.value,
    required this.level,
    required this.display,
    this.max = 100,
    this.unit,
    this.label,
    this.size = 168,
  });

  @override
  Widget build(BuildContext context) {
    final t = (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: t),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _ArcPainter(v, level.mark),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: display,
                    style: K.hero.copyWith(color: level.ink, fontSize: size * 0.30),
                    children: [
                      if (unit != null)
                        TextSpan(text: unit, style: K.heroUnit),
                    ],
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(label!.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: level.ink)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double t;
  final Color color;
  _ArcPainter(this.t, this.color);

  static const _sweep = 260 * math.pi / 180;
  static const _start = (90 + 50) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke,
        size.width - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = K.line2;
    canvas.drawArc(rect, _start, _sweep, false, track);

    if (t <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, _start, _sweep * t, false, fill);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.t != t || old.color != color;
}

/// Satir sonunda duran kucuk egilim cizgisi.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double width;
  final double height;

  const Sparkline(this.values,
      {super.key, this.color = K.ink3, this.width = 54, this.height = 20});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    Offset pt(int i) => Offset(
        i * size.width / (v.length - 1), size.height * (1 - (v[i] - lo) / span));

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color);
    canvas.drawCircle(pt(v.length - 1), 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

/// Ekran acilisinda yumusak giris. Icerik gorunur halde baslar, yalnizca
/// hafifce yukselir — hicbir sey gizli kalmaz.
class FadeUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeUp({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: 0.35 + 0.65 * v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
