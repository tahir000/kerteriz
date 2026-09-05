import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../theme.dart';
import 'gauge.dart';

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: K.eyebrow);
}

class ScreenHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  const ScreenHead(this.eyebrow, this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 26, K.gutter, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 5),
          Text(title, style: K.title),
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, K.sectionGap, K.gutter, 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: level.tint, borderRadius: BorderRadius.circular(5)),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: level.ink)),
      );
}

/// Uc bolgeli olcek: kirmizi / turuncu / yesil zemin, siyah igne.
class ZoneMeter extends StatelessWidget {
  final double value, min, max;
  final List<MapEntry<double, Level>> zones; // ust sinir -> seviye
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
                  borderRadius: BorderRadius.circular(3),
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
                      border: Border.all(color: Colors.white, width: 1.2)),
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
      // Wrap icinde Flexible kullanilamaz; Wrap zaten genisligi kisitliyor.
      sub.add(Text(subtitle!, style: K.rowSub));
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: K.gutter, vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: K.line2, width: 1))),
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
                        style: const TextStyle(fontSize: 12, color: K.ink3)),
                ],
              ),
            ),
          ),
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.chevron_right, size: 18, color: K.ink3),
          ),
      ]),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class NoteBlock extends StatelessWidget {
  final String text;
  const NoteBlock(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(K.gutter, 18, K.gutter, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: K.fill, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: K.note),
      );
}

class LevelScale extends StatelessWidget {
  const LevelScale({super.key});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(K.gutter, 12, K.gutter, 0),
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
                      color: e.key.mark, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              Text(e.value, style: const TextStyle(fontSize: 11, color: K.ink2)),
            ]),
        ]));
  }
}
