import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/l10n.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/ui/ozet_ekrani.dart';

import 'helpers.dart';

/// Özet ekranı halkalarla çiziliyor mu, dokununca alt sayfalar açılıyor mu.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
    await initializeDateFormatting('en');
  });

  List<DayRecord> veri() {
    final n = DateTime.now();
    final days = gunler(30, son: DateTime(n.year, n.month, n.day),
        f: (date, i) {
      final g = gun(date,
          asleep: 400 + (i * 37) % 120,
          hrv: 45 + (i * 7) % 12,
          rhr: 54 + (i % 3).toDouble(),
          steps: 4000 + (i * 1733) % 9000,
          zoneMinutes: [0, 20, 10, 5, 1],
          nightHr: [
            for (var m = 0; m < 480; m += 10) HrSample(m, 70 - m / 20),
          ]);
      // SpO2 yalnızca birkaç gün önce gelmiş: son ölçüm bugün değil.
      if (i == 25) g.spo2Avg = 96.4;
      g.respiratory = 14.2;
      return g;
    });
    MetricsEngine.run(days);
    return days;
  }

  for (final dil in ['tr', 'en']) {
    testWidgets('özet ekranı çiziliyor ve halkalar açılıyor ($dil)',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      DayRecord.locale = dil;
      S.aktifDil = dil;
      final days = veri();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(dil),
        supportedLocales: S.supported,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: OzetEkrani(days, allDays: days)),
      ));
      await tester.pumpAndSettle();
      final s = S.forCode(dil);

      // Hazırlık: işlenmiş veri, girdileri listeleniyor.
      await tester.tap(find.text(s.t('today.readiness')));
      await tester.pumpAndSettle();
      expect(find.text(buyukHarf(s.t('sum.inputs'), dil)), findsOneWidget);
      Navigator.of(tester.element(find.byType(OzetEkrani))).pop();
      await tester.pumpAndSettle();

      // SpO2: ham ölçüm, son ölçüm günü gösteriliyor.
      await tester.ensureVisible(find.text('SpO2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SpO2'));
      await tester.pumpAndSettle();
      expect(find.text(buyukHarf(s.t('sum.lastReading'), dil)), findsOneWidget);
      expect(find.textContaining(s.t2('sum.daysAgo', {'n': '4'})),
          findsOneWidget);
    });
  }
}
