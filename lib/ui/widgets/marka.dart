import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Kerteriz simgesi: koyu yuvarlak kare, içinde altı açık beyaz halka,
/// halkanın sağ üstünde yeşil nokta.
///
/// [ilerleme] 0 iken halka yalnızca soluk izinden ibaret, 1 iken simgenin
/// kendisi. Arada halka sol bacaktan başlayıp saat yönünde doluyor; yeşil
/// nokta da dolum oraya vardığında beliriyor.
class MarkaCizer extends CustomPainter {
  final double ilerleme;

  /// Dolum bittikten sonra yeşil noktanın çevresinde soluk bir halka
  /// gidip geliyor. Ekranın donmadığını gösteren tek hareket bu.
  final double nabiz;
  final Color kare;
  MarkaCizer(this.ilerleme, this.nabiz, this.kare);

  /// Halka altta açık: boşluk 6 yönünde, 60 derece genişliğinde.
  static const _bas = 120 * math.pi / 180;
  static const _tarama = 300 * math.pi / 180;

  /// Yeşil noktanın halka üzerindeki yeri (saat 1-2 arası).
  static const _noktaAci = -38 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(k * 0.215),
    );
    canvas.drawRRect(rrect, Paint()..color = kare);

    final merkez = Offset(size.width / 2, size.height * 0.455);
    final disR = k * 0.235;
    final kalinlik = k * 0.102;
    final r = disR - kalinlik / 2;
    final yay = Rect.fromCircle(center: merkez, radius: r);

    // Soluk iz: halkanın nereye kadar doldurulacağı baştan belli olsun.
    canvas.drawArc(
      yay,
      _bas,
      _tarama,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    final t = ilerleme.clamp(0.0, 1.0);
    if (t > 0) {
      canvas.drawArc(
        yay,
        _bas,
        _tarama * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kalinlik
          ..color = Colors.white,
      );
    }

    // Nokta halkanın o noktasına varınca beliriyor: dolum onu "açıyor".
    final noktaT = ((_noktaAci + 2 * math.pi) - _bas) / _tarama;
    final gorunur = ((t - noktaT) / 0.12).clamp(0.0, 1.0);
    if (gorunur > 0) {
      final c = merkez +
          Offset(math.cos(_noktaAci), math.sin(_noktaAci)) * (r * 1.06);
      const yesil = Color(0xFF2FAE55);
      final yaricap = k * 0.068 * (0.6 + 0.4 * gorunur);
      if (t >= 1 && nabiz > 0) {
        canvas.drawCircle(
          c,
          yaricap * (1.25 + 0.55 * nabiz),
          Paint()..color = yesil.withValues(alpha: 0.28 * (1 - nabiz)),
        );
      }
      canvas.drawCircle(
        c,
        yaricap,
        Paint()..color = yesil.withValues(alpha: gorunur),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MarkaCizer old) =>
      old.ilerleme != ilerleme || old.nabiz != nabiz || old.kare != kare;
}

/// Açılış ekranı: simge bir kez dolar, sonra okuma bitene kadar dolu
/// halde bekler.
///
/// Dolum bir yüzde göstergesi değil: Health Connect okumasının ne kadar
/// süreceği baştan bilinmiyor. Bu yüzden dolum bir kez oynuyor ve orada
/// kalıyor; bekleyişi anlatan tek hareket yeşil noktanın çevresindeki
/// soluk halka. Tekrar tekrar dolan bir halka "hiç ilerlemiyor" hissi
/// veriyordu.
class KerterizYukleniyor extends StatefulWidget {
  final String metin;
  const KerterizYukleniyor(this.metin, {super.key});

  @override
  State<KerterizYukleniyor> createState() => _KerterizYukleniyorState();
}

class _KerterizYukleniyorState extends State<KerterizYukleniyor>
    with TickerProviderStateMixin {
  /// Tek seferlik dolum.
  late final AnimationController _dolum = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  /// Dolumdan sonraki bekleyiş işareti.
  late final AnimationController _nefes = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _dolum.dispose();
    _nefes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kareRengi =
        K.koyu ? const Color(0xFF23262C) : const Color(0xFF1C1D20);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: Listenable.merge([_dolum, _nefes]),
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_dolum.value);
            // Nefes yalnızca dolum bittikten sonra çalışıyor; dolarken
            // simge sabit duruyor ki dolum okunabilsin.
            final n = t >= 1 ? _nefes.value : 0.0;
            return Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(96 * 0.215),
                boxShadow: K.golge,
              ),
              child: CustomPaint(painter: MarkaCizer(t, n, kareRengi)),
            );
          },
        ),
        const SizedBox(height: 22),
        Text(widget.metin, style: K.caption, textAlign: TextAlign.center),
      ]),
    );
  }
}
