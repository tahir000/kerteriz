import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n.dart';

import '../../theme.dart';

/// Hero değerler için yay göstergesi.
///
/// 260 derecelik bir yay: soluk bir iz üzerine seviye renginde dolan bir kavis,
/// ortasında sayının kendisi. Renk tek başına anlam taşımıyor — sayı da,
/// altındaki etiket de orada.
class ArcGauge extends StatelessWidget {
  final double value; // 0..max
  final double max;

  /// null ise gösterge nötr çizilir: sayı var ama henüz bir seviyeye
  /// oturtulamıyor demektir (taban çizgi dolmamış, veri yetmiyor).
  final Level? level;
  final String display; // ortada yazan
  final String? unit;
  final String? label; // yayın altındaki küçük etiket
  final double size;

  /// Seviye anlamı olmayan göstergeler için dolgu rengi (döngü günü gibi).
  /// Verilmezse seviyenin rengi, o da yoksa nötr gri.
  final Color? renk;

  /// true ise ortadaki sayı da yayla birlikte sıfırdan sayarak dolar.
  /// Tam sayı olmayan gösterimlerde (0.9 gibi) kapatılmalı.
  final bool sayiyor;

  const ArcGauge({
    super.key,
    required this.value,
    this.level,
    required this.display,
    this.max = 100,
    this.unit,
    this.label,
    this.size = 168,
    this.sayiyor = false,
    this.renk,
  });

  @override
  Widget build(BuildContext context) {
    final t = (value / max).clamp(0.0, 1.0);
    final isaret = renk ?? level?.mark ?? K.ink4;
    final murekkep = level?.ink ?? K.ink;
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: t),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _ArcPainter(v, isaret),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Yay dolarken ortadaki sayı da onunla birlikte sayıyor:
                // ikisi aynı hareketin parçası gibi okunuyor.
                RichText(
                  text: TextSpan(
                    text: sayiyor
                        ? (value * v / (t == 0 ? 1 : t)).toStringAsFixed(0)
                        : display,
                    style: K.hero.copyWith(color: murekkep, fontSize: size * 0.30),
                    children: [
                      if (unit != null)
                        TextSpan(text: unit, style: K.heroUnit),
                    ],
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  // Yayın iç genişliğini aşmasın: uzun etiket yayın çizgisinin
                  // üstüne biniyordu.
                  SizedBox(
                    width: size * 0.6,
                    child: Text(buyukHarf(label!),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: murekkep)),
                  ),
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

/// Satır sonunda duran küçük eğilim çizgisi.
class Sparkline extends StatelessWidget {
  final List<double> values;
  /// null ise tema jetonundan alınır. Varsayılan olarak `K.ink3` yazılamaz:
  /// tema renkleri artık sabit değil, gece moduna göre değişen getter.
  final Color? color;
  final double width;
  final double height;

  const Sparkline(this.values,
      {super.key, this.color, this.width = 54, this.height = 20});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(values, color ?? K.ink3)),
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

/// Ekran açılışında kademeli giriş. İçerik görünür halde başlar, yalnızca
/// aşağıdan yukarı süzülür: hiçbir şey gizli kalmaz, ekran da donuk durmaz.
/// [index] büyüdükçe giriş biraz gecikir; gecikme 10. öğeden sonra sabitlenir
/// ki uzun listelerin sonu geç gelmesin.
class FadeUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeUp({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final kademe = (index > 10 ? 10 : index) * 55;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + kademe),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: 0.25 + 0.75 * v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

