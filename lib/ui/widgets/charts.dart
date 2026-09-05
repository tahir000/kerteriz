import 'package:flutter/material.dart';

import '../../data/day_record.dart';
import '../../theme.dart';

class Bar {
  final double value;
  final Level? level;
  final bool highlight;
  const Bar(this.value, {this.level, this.highlight = false});
}

class BarSeriesChart extends StatelessWidget {
  final List<Bar> bars;
  final double height;
  final double? rule;
  final String? ruleLabel;
  final String leftLabel, rightLabel;

  const BarSeriesChart({
    super.key,
    required this.bars,
    this.height = 118,
    this.rule,
    this.ruleLabel,
    this.leftLabel = '',
    this.rightLabel = '',
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
                painter: _BarPainter(bars, rule, ruleLabel)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(leftLabel, style: K.axis),
            Text(rightLabel, style: K.axis),
          ]),
        ]),
      );
}

class _BarPainter extends CustomPainter {
  final List<Bar> bars;
  final double? rule;
  final String? ruleLabel;
  _BarPainter(this.bars, this.rule, this.ruleLabel);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    var maxV = 0.0;
    for (final b in bars) {
      if (b.value > maxV) maxV = b.value;
    }
    if (rule != null && rule! > maxV) maxV = rule!;
    maxV *= 1.12;
    if (maxV <= 0) return;

    final n = bars.length;
    final slot = size.width / n;
    final gap = n > 40 ? 1.0 : 2.0;
    final bw = (slot - gap).clamp(1.0, slot);
    final p = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final h = (b.value / maxV) * size.height;
      p.color = b.highlight
          ? K.accent
          : (b.level?.mark ?? K.line);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot, size.height - h, bw, h < 1.5 ? 1.5 : h),
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
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
                painter: _LinePainter(values, bandLow, bandHigh, endLevel, decimals)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(leftLabel, style: K.axis),
            Text(rightLabel, style: K.axis),
          ]),
        ]),
      );
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? bandLow, bandHigh;
  final Level? endLevel;
  final int decimals;
  _LinePainter(this.values, this.bandLow, this.bandHigh, this.endLevel, this.decimals);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (bandLow != null && bandLow!.isNotEmpty) {
      final bl = bandLow!.reduce((a, b) => a < b ? a : b);
      if (bl < lo) lo = bl;
    }
    if (bandHigh != null && bandHigh!.isNotEmpty) {
      final bh = bandHigh!.reduce((a, b) => a > b ? a : b);
      if (bh > hi) hi = bh;
    }
    final pad = (hi - lo) * 0.18;
    lo -= pad == 0 ? 1 : pad;
    hi += pad == 0 ? 1 : pad;

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

    if (bandLow != null && bandHigh != null && bandLow!.length == values.length) {
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

    // cizginin altina cok soluk bir alan: egilimi okumayi kolaylastirir
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
    canvas.drawCircle(last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 4.2, Paint()..color = endLevel?.mark ?? K.accent);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Gecenin evre serisi — dort satir, her segment bir cubuk.
class Hypnogram extends StatelessWidget {
  final DayRecord day;
  final Map<String, String> names;
  const Hypnogram(this.day, {super.key, required this.names});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 104,
            width: double.infinity,
            child: CustomPaint(painter: _HypnoPainter(day, names)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtClock(day.bedStart), style: K.axis),
            Text(fmtClock(day.wakeEnd), style: K.axis),
          ]),
        ]),
      );
}

class _HypnoPainter extends CustomPainter {
  final DayRecord d;
  final Map<String, String> names;
  _HypnoPainter(this.d, this.names);

  static const rows = {'awake': 0, 'rem': 1, 'light': 2, 'deep': 3};
  static const order = ['awake', 'rem', 'light', 'deep'];
  static const colors = [K.stageWake, K.stageRem, K.stageLight, K.stageDeep];

  @override
  void paint(Canvas canvas, Size size) {
    if (d.bedStart == null || d.timeInBed <= 0) return;
    const gutter = 46.0;
    final plot = size.width - gutter;
    const rh = 20.0, gap = 6.0;

    for (var i = 0; i < order.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: names[order[i]] ?? order[i], style: K.axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, i * (rh + gap) + 2));
    }

    final p = Paint()..style = PaintingStyle.fill;
    for (final s in d.segments) {
      final row = rows[s.stage];
      if (row == null) continue;
      final t0 = s.start.difference(d.bedStart!).inMinutes / d.timeInBed;
      final w = (s.minutes / d.timeInBed) * plot;
      p.color = colors[row];
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
  const StackBar(this.parts, {super.key});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          for (final e in parts)
            Expanded(
              flex: (e.value / total * 1000).round().clamp(1, 1000),
              child: Container(
                height: 16,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                    color: e.key, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uyku penceresi haritasi: her satir bir gece, bant uykuda gecen sure.
class SleepRaster extends StatelessWidget {
  final List<DayRecord> days;
  const SleepRaster(this.days, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: days.length * 7.6 + 4,
            width: double.infinity,
            child: CustomPaint(painter: _RasterPainter(days)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
            Text('20:00', style: K.axis),
            Text('04:00', style: K.axis),
            Text('12:00', style: K.axis),
          ]),
        ]),
      );
}

class _RasterPainter extends CustomPainter {
  final List<DayRecord> days;
  _RasterPainter(this.days);

  @override
  void paint(Canvas canvas, Size size) {
    const rh = 6.0, gap = 1.6, span = 960.0; // 20:00 -> 12:00
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final y = i * (rh + gap);
      p.color = K.line2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, y, size.width, rh), const Radius.circular(1)),
        p,
      );
      final b = d.bedOffset;
      if (b == null || d.timeInBed <= 0) continue;
      final x = (b / span).clamp(0.0, 1.0) * size.width;
      final w = (d.timeInBed / span).clamp(0.0, 1.0) * size.width;
      p.color = Levels.score(d.sleepScore).mark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w < 1 ? 1 : w, rh), const Radius.circular(1)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RasterPainter old) => true;
}
