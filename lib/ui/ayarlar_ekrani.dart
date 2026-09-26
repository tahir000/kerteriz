import 'package:flutter/material.dart';

import '../config.dart';
import '../data/ayarlar.dart';
import '../l10n.dart';
import '../theme.dart';
import 'widgets/kit.dart';

/// Ayarlar. Şimdilik tek başlık altında tema tercihi var; uygulamanın
/// kişisel sabitleri (hedefler, porsiyon) koda gömülü olduğu için burada
/// düzenlenmiyor.
class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(K.gutter - 6, 8, K.gutter, 0),
            child: Row(children: [
              // Geri düğmesi: sistemin kendi geri hareketi de çalışıyor,
              // bu yalnızca görünür bir çıkış.
              Basilabilir(
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back, size: 22, color: K.ink),
                ),
              ),
            ]),
          ),
          ScreenHead(s.t('app.name'), s.t('settings.title'), ayarlar: false),

          SectionLabel(s.t('settings.appearance')),
          // Tercih diske yazılıyor; uygulamayı kapatıp açınca korunuyor.
          ValueListenableBuilder<TemaTercihi>(
            valueListenable: Ayarlar.tema,
            builder: (context, tercih, _) => SegmentliSecici(
              etiketler: [
                s.t('settings.themeSystem'),
                s.t('settings.themeLight'),
                s.t('settings.themeDark'),
              ],
              secili: tercih.index,
              onChanged: (i) => Ayarlar.temaYaz(TemaTercihi.values[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(K.gutter + 2, 8, K.gutter, 2),
            child: Text(s.t('settings.themeSub'), style: K.note),
          ),

          SectionLabel(s.t('settings.about')),
          MetricRow(
              title: s.t('data.version'),
              subtitle: s.t('data.versionSub'),
              value: Config.version),
          NoteBlock(s.t('settings.dataTabSub')),
          NoteBlock(s.t('data.privacyNote')),
        ]),
      ),
    );
  }
}

/// Başlıkların sağındaki dişli. [ScreenHead] içinden çağrılıyor, böylece
/// her ekranın üstünde aynı yerde duruyor ve içerikle birlikte kayıyor.
class AyarDugmesi extends StatelessWidget {
  const AyarDugmesi({super.key});

  @override
  Widget build(BuildContext context) => Basilabilir(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AyarlarEkrani()),
        ),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: K.card,
            borderRadius: BorderRadius.circular(K.kapsul),
            boxShadow: K.cubukGolge,
          ),
          child: Icon(Icons.tune, size: 19, color: K.ink2),
        ),
      );
}
