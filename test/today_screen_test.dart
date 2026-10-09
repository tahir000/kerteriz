import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/l10n.dart';
import 'package:kerteriz/metrics/engine.dart';
import 'package:kerteriz/data/ayarlar.dart';
import 'package:kerteriz/ui/ayarlar_ekrani.dart';
import 'package:kerteriz/ui/dongu_ekrani.dart';
import 'package:kerteriz/ui/gun_ici_ekrani.dart';
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
    // Bugünün kaydı gerçek bugün olsun ki gün içi bölümü görünsün.
    MetricsEngine.run(days);
    return days;
  }

  List<DayRecord> bugunlu() {
    final n = DateTime.now();
    final days = gunler(30, son: DateTime(n.year, n.month, n.day), f: (date, i) {
      final g = gun(date, asleep: 400 + (i * 37) % 120, steps: 4000 + (i * 1733) % 9000);
      g.gunNabzi = [for (var b = 0; b < DayRecord.dilimSayisi; b++) 70.0 + (b % 7) * 4];
      g.gunAdim = [for (var b = 0; b < DayRecord.dilimSayisi; b++) b % 9 == 0 ? 600 : 0];
      if (i == 28) {
        g.antrenmanlar = [
          Antrenman('RUNNING', DateTime(date.year, date.month, date.day, 18),
              DateTime(date.year, date.month, date.day, 18, 45))
            ..ortNabiz = 150
            ..maksNabiz = 172
            ..yukHam = 140
            ..bolge = [0, 5, 10, 20, 8]
        ];
      }
      return g;
    });
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
      final uyari = find.textContaining(s.t('today.nightHrHigh').split('{').first);
      await tester.scrollUntilVisible(uyari, 200, scrollable: kaydir);
      expect(uyari, findsOneWidget);

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

    testWidgets('gün içi bölümü çiziliyor ($dil)', (tester) async {
      final d = bugunlu();
      await ciz(tester, TodayScreen(d, allDays: d), dil);
      final s = S.forCode(dil);
      await tester.scrollUntilVisible(find.text(s.t('intraday.stress')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(s.t('intraday.energy')), findsOneWidget);
    });

    testWidgets('gün içi ayrıntısı çiziliyor ($dil)', (tester) async {
      final d = bugunlu();
      await ciz(tester, GunIciEkrani(days: d, bugun: d.last), dil);
      final s = S.forCode(dil);
      expect(find.text(s.t('intraday.energyStart')), findsOneWidget);
      final saatlik = find.text(s.t('intraday.stressHourly').toUpperCase());
      await tester.scrollUntilVisible(saatlik, 300,
          scrollable: find.byType(Scrollable).first);
      expect(saatlik, findsOneWidget);
    });

    testWidgets('döngü satırı ve cihaz notu çiziliyor ($dil)', (tester) async {
      final n = DateTime.now();
      final d = gunler(40, son: DateTime(n.year, n.month, n.day), f: (date, i) {
        final g = gun(date, hrv: null, rhr: 56 + (i % 3).toDouble());
        g.regl = i % 28 < 4;
        return g;
      });
      MetricsEngine.run(d);
      await ciz(tester, TodayScreen(d, allDays: d, kalpKaynagi: 'Samsung Health'), dil);
      final s = S.forCode(dil);
      final not = find.text(s.t2('device.title', {'src': 'Samsung Health'}));
      await tester.scrollUntilVisible(not, 200, scrollable: find.byType(Scrollable).first);
      expect(not, findsOneWidget);
      final dongu = find.text(s.t('cycle.title'));
      await tester.scrollUntilVisible(dongu, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(dongu);
      await tester.pumpAndSettle();
      expect(find.textContaining(s.t('cycle.note').substring(0, 20)), findsOneWidget);
    });

    testWidgets('döngü sekmesi çiziliyor ($dil)', (tester) async {
      final n = DateTime.now();
      final d = gunler(70, son: DateTime(n.year, n.month, n.day), f: (date, i) {
        final g = gun(date, rhr: 56 + (i % 3).toDouble());
        g.reglHc = g.regl = i % 28 < 4;
        return g;
      });
      MetricsEngine.run(d);
      await ciz(tester, DonguEkrani(days: d), dil);
      final s = S.forCode(dil);
      expect(find.text(s.t('cycle.next')), findsOneWidget);
      final takvim = find.text(s.t('cycle.calendar').toUpperCase());
      await tester.scrollUntilVisible(takvim, 300,
          scrollable: find.byType(Scrollable).first);
      expect(takvim, findsOneWidget);
    });

    testWidgets('döngü sekmesi veri yokken boş durum ($dil)', (tester) async {
      final d = gunler(10);
      MetricsEngine.run(d);
      await ciz(tester, DonguEkrani(days: d), dil);
      expect(find.text(S.forCode(dil).t('cycle.emptyTitle')), findsOneWidget);
    });

    testWidgets('ayarlar: kadın seçiliyken döngü bölümü ($dil)', (tester) async {
      Ayarlar.cinsiyet = 'kadin';
      addTearDown(() => Ayarlar.cinsiyet = null);
      await ciz(tester, const AyarlarEkrani(), dil);
      final s = S.forCode(dil);
      final bolum = find.text(s.t('settings.cycleAdjust'));
      await tester.scrollUntilVisible(bolum, 300,
          scrollable: find.byType(Scrollable).first);
      expect(bolum, findsOneWidget);
    });

    testWidgets('antrenman listesi ve ayrıntısı çiziliyor ($dil)', (tester) async {
      final d = bugunlu();
      await ciz(tester, LoadScreen(d), dil);
      final s = S.forCode(dil);
      final kosu = find.text(s.t('workout.type.RUNNING'));
      expect(kosu, findsOneWidget);
      await tester.tap(kosu);
      await tester.pumpAndSettle();
      expect(find.text(s.t('workout.load')), findsOneWidget);
    });

    testWidgets('öteki ekranlar çiziliyor ($dil)', (tester) async {
      final d = veri();
      await ciz(tester, SleepScreen(d), dil);
      await ciz(tester, LoadScreen(d), dil);
      await ciz(tester, HeartScreen(d), dil);
    });
  }
}
