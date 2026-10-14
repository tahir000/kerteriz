import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/l10n.dart';
import 'package:kerteriz/theme.dart';
import 'package:kerteriz/ui/widgets/charts.dart';

/// Grafiğe dokununca kart büyüyor ve dokunulan öğenin ayrıntısı görünüyor.
void main() {
  Future<void> kur(WidgetTester tester, Widget grafik) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: S.supported,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: ListView(children: [grafik])),
    ));
    await tester.pumpAndSettle();
  }

  double olcek(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;

  testWidgets('sütuna dokununca tarih ve değer balonda', (tester) async {
    await kur(
      tester,
      BarSeriesChart(
        bars: const [Bar(40), Bar(80), Bar(60)],
        labels: const ['1 Eki', '2 Eki', '3 Eki'],
        format: (v) => '${v.round()} puan',
      ),
    );
    expect(find.text('2 Eki'), findsNothing);
    expect(olcek(tester), 1);

    final kutu = tester.getRect(find
        .descendant(
            of: find.byType(BarSeriesChart),
            matching: find.byType(CustomPaint))
        .first);
    await tester.tapAt(kutu.center);
    await tester.pumpAndSettle();
    expect(find.text('2 Eki'), findsOneWidget);
    expect(find.text('80 puan'), findsOneWidget);
    expect(olcek(tester), greaterThan(1));

    // Aynı sütuna yeniden dokunmak seçimi kapatıyor.
    await tester.tapAt(kutu.center);
    await tester.pumpAndSettle();
    expect(olcek(tester), 1);
  });

  testWidgets('seçim birkaç saniye sonra kendiliğinden kapanıyor',
      (tester) async {
    await kur(
      tester,
      const LineSeriesChart(
        values: [50, 55, 52, 58],
        labels: ['a', 'b', 'c', 'son'],
        unit: ' ms',
      ),
    );
    final kutu = tester.getRect(find
        .descendant(
            of: find.byType(LineSeriesChart),
            matching: find.byType(CustomPaint))
        .first);
    await tester.tapAt(kutu.centerRight - const Offset(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('58 ms'), findsOneWidget);
    expect(olcek(tester), greaterThan(1));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(olcek(tester), 1);
  });

  testWidgets('evre şeridinde parçanın adı ve süresi', (tester) async {
    await kur(
      tester,
      StackBar([
        MapEntry(K.stageDeep, 90),
        MapEntry(K.stageRem, 30),
      ], names: const ['Derin', 'REM']),
    );
    final kutu = tester.getRect(find.byType(Row).first);
    await tester.tapAt(kutu.centerLeft + const Offset(10, 0));
    await tester.pumpAndSettle();
    expect(find.text('Derin'), findsOneWidget);
    expect(find.text('1 sa 30 dk'), findsOneWidget);
    expect(find.text('%75'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
