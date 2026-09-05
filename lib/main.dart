import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/day_record.dart';
import 'l10n.dart';
import 'theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Desteklenen her dil icin tarih adlarini yukle.
  for (final l in S.supported) {
    await initializeDateFormatting(l.languageCode);
  }
  runApp(const KerterizApp());
}

class KerterizApp extends StatelessWidget {
  const KerterizApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kerteriz',
        debugShowCheckedModeBanner: false,
        theme: K.theme,
        supportedLocales: S.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Cihaz dili destekleniyorsa onu, degilse Ingilizceyi kullan.
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
