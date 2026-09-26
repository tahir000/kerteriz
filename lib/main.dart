import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/ayarlar.dart';
import 'data/day_record.dart';
import 'data/tani.dart';
import 'l10n.dart';
import 'theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  // Çerçevenin yakaladığı hataları da ize yaz: ekran görünmeden ölürse
  // bir sonraki açılışta sebebini okuyabilelim.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Tani.baslat();
    await Tani.iz('acilis');

    FlutterError.onError = (details) {
      Tani.iz('FLUTTER HATASI: ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };

    // Desteklenen her dil için tarih adlarını yükle.
    for (final l in S.supported) {
      await initializeDateFormatting(l.languageCode);
    }
    await Tani.iz('tarih-adlari');
    // Tema tercihi ilk çerçeveden önce okunuyor: uygulama açık temayla
    // parlayıp sonra koyuya dönmesin.
    await Ayarlar.oku();
    await Tani.iz('ayarlar');
    runApp(const KerterizApp());
  }, (e, s) {
    Tani.iz('YAKALANMAYAN HATA: $e');
  });
}

class KerterizApp extends StatefulWidget {
  const KerterizApp({super.key});

  @override
  State<KerterizApp> createState() => _KerterizAppState();
}

/// Tema tek bir yerden kuruluyor.
///
/// [K.koyu] bir `static` bayrak, tema renkleri de ona bakan getter'lar:
/// bayrak her yapımda burada güncelleniyor, altındaki bütün ağaç doğru
/// paletle çiziliyor. Gözlemci olmamızın sebebi sistem gece modu:
/// tercih "sistem" iken cihaz temasını değiştirince haber almalıyız.
class _KerterizAppState extends State<KerterizApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Ayarlar.tema.addListener(_yenile);
  }

  @override
  void dispose() {
    Ayarlar.tema.removeListener(_yenile);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  @override
  void didChangePlatformBrightness() => _yenile();

  @override
  Widget build(BuildContext context) {
    // MediaQuery değil PlatformDispatcher: MaterialApp'in üstünde henüz
    // MediaQuery yok, cihaz parlaklığı ancak buradan okunabiliyor.
    final sistemKoyu = WidgetsBinding.instance.platformDispatcher
            .platformBrightness ==
        Brightness.dark;
    final tercih = Ayarlar.tema.value;
    K.koyu = tercih == TemaTercihi.koyu ||
        (tercih == TemaTercihi.sistem && sistemKoyu);

    // Durum çubuğu simgeleri zeminle ters olmalı, yoksa koyu temada
    // beyaz zemine beyaz saat düşüyor.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: K.koyu ? Brightness.light : Brightness.dark,
      statusBarBrightness: K.koyu ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: K.card,
      systemNavigationBarIconBrightness:
          K.koyu ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'Kerteriz',
      debugShowCheckedModeBanner: false,
      theme: K.theme,
      supportedLocales: S.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Cihaz dili destekleniyorsa onu, değilse İngilizceyi kullan.
      localeResolutionCallback: (device, supported) {
        final match = supported.firstWhere(
          (l) => l.languageCode == device?.languageCode,
          orElse: () => const Locale('en'),
        );
        DayRecord.locale = match.languageCode;
        return match;
      },
      home: const Shell(),
    );
  }
}
