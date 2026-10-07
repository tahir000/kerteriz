import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/l10n.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/ui/screens.dart';
import 'package:kerteriz/ui/verin_ekrani.dart';

import 'helpers.dart';

/// Ekranlar sentetik 30 günle hatasız çiziliyor mu. Taşma (overflow) da
/// Flutter testinde hata sayılır, yani dar ekranda kırılan satır burada düşer.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
    await initializeDateFormatting('en');
  });

  Future<void> ciz(WidgetTester tester, Widget ekran, String dil) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    DayRecord.locale = dil;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(dil),
      supportedLocales: S.supported,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: ekran),
    ));
    await tester.pumpAndSettle();
  }

  List<DayRecord> veri({int n = 30}) {
    final days = gunler(n, f: (date, i) => gun(date,
        asleep: 400 + (i * 37) % 120,
        hrv: 45 + (i * 7) % 12,
        rhr: i >= n - 2 ? 66 : 54 + (i % 3).toDouble(),
        hydrationMl: (i * 500) % 3500,
        steps: 4000 + (i * 1733) % 9000,
        bedHour: i.isEven ? 22 : 23));
    MetricsEngine.run(days);
    return days;
  }

  for (final dil in ['tr', 'en']) {
    testWidgets('Bugün ekranı çiziliyor ($dil)', (tester) async {
      await ciz(tester, TodayScreen(veri()), dil);
      final s = S.forCode(dil);
      final kaydir = find.byType(Scrollable).first;
      expect(find.text(s.t('today.title')), findsWidgets);

      // Günün cümlesi en üstte: ton + sebep + yatış saati tek metin.
      final yatis = s.t('headline.bed').split('{').first;
      expect(find.textContaining(yatis), findsOneWidget);
      // Gece nabzı son iki gece yüksek: hem cümlede hem uyarıda.
      final uyari = s.t('today.nightHrHigh').split('{').first;
      expect(find.textContaining(uyari), findsOneWidget);

      await tester.scrollUntilVisible(find.text(s.t('today.bedtime')), 300,
          scrollable: kaydir);
      expect(find.text(s.t('tags.title')), findsOneWidget);

      // Haftalık özet pazartesi dışında kapalı; dokununca açılıyor.
      final hafta = find.text(s.t('today.week').toUpperCase());
      await tester.scrollUntilVisible(hafta, 300, scrollable: kaydir);
      if (find.text(s.t('today.weekReadiness')).evaluate().isEmpty) {
        await tester.tap(hafta);
        await tester.pumpAndSettle();
      }
      expect(find.text(s.t('today.weekReadiness')), findsOneWidget);

      // "Senin verin ne diyor" ekranı açılıyor ve çiziliyor.
      final giris = find.text(s.t('insights.title'));
      await tester.scrollUntilVisible(giris, -300, scrollable: kaydir);
      await tester.tap(giris);
      await tester.pumpAndSettle();
      expect(find.text(s.t('insights.intro')), findsOneWidget);
      // 30 günlük sentetik veride otomatik karşılaştırmalar dolu olmalı.
      await tester.scrollUntilVisible(
          find.text(s.t('insights.adim.title')), 300,
          scrollable: find.byType(Scrollable).last);
    });

    testWidgets('Bugün ekranı az veriyle çiziliyor ($dil)', (tester) async {
      await ciz(tester, TodayScreen(veri(n: 2)), dil);
      expect(find.text(S.forCode(dil).t('today.weekReadiness')), findsNothing);
    });

    testWidgets('veri ekranı az veriyle bekleme metinlerini gösteriyor ($dil)',
        (tester) async {
      final d = veri(n: 3);
      await ciz(tester, VerinEkrani(days: d, allDays: d), dil);
      final bos = find.text(S.forCode(dil).t('insights.autoNone'));
      await tester.scrollUntilVisible(bos, 300,
          scrollable: find.byType(Scrollable).last);
      expect(bos, findsOneWidget);
    });

    testWidgets('öteki ekranlar çiziliyor ($dil)', (tester) async {
      final d = veri();
      await ciz(tester, SleepScreen(d), dil);
      await ciz(tester, LoadScreen(d), dil);
      await ciz(tester, HeartScreen(d), dil);
    });
  }
}
