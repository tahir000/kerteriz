import 'package:flutter/material.dart';

import '../config.dart';
import '../data/ayarlar.dart';
import '../l10n.dart';
import '../theme.dart';
import 'widgets/kit.dart';

/// Ayarlar: görünüm, kişisel değerler ve günlük hedefler.
///
/// Bu ekranın var olma sebebi tek cümleyle şu: yaş ve hedefler eskiden
/// `lib/config.dart` içinde derlemeye gömülüydü. Kendi telefonunda çalışan
/// kişisel bir yapıda bu yeterliydi; başkasının kurduğu bir uygulamada
/// nabız bölgelerini 30 yaşa göre hesaplamak yanlış sonuç üretir.
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  /// Değeri yazar, sonra ekranı yeniler. [Ayarlar] alanları düz `static`
  /// olduğu için yeniden çizmek yeterli.
  Future<void> _yaz(Future<void> Function() islem) async {
    await islem();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 44), children: [
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

          // ---- görünüm ----
          SectionLabel(s.t('settings.appearance')),
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

          // ---- kişisel ----
          SectionLabel(s.t('settings.personal')),
          SayiSatiri(
            title: s.t('settings.age'),
            subtitle: s.t2('settings.ageSub',
                {'hr': Ayarlar.hrMax.round().toString()}),
            deger: Ayarlar.yas,
            adim: 1,
            enAz: Ayarlar.sinirlar['yas']![0],
            enCok: Ayarlar.sinirlar['yas']![1],
            birim: s.t('unit.year'),
            onChanged: (v) => _yaz(() => Ayarlar.guncelle(yas: v)),
          ),
          NoteBlock(s.t('settings.ageNote')),

          // ---- hedefler ----
          SectionLabel(s.t('settings.goals')),
          SayiSatiri(
            title: s.t('settings.waterGoal'),
            subtitle: s.t('settings.waterGoalSub'),
            deger: Ayarlar.suHedefiMl,
            adim: 250,
            enAz: Ayarlar.sinirlar['su']![0],
            enCok: Ayarlar.sinirlar['su']![1],
            birim: s.t('unit.ml'),
            onChanged: (v) => _yaz(() => Ayarlar.guncelle(suHedefiMl: v)),
          ),
          SayiSatiri(
            title: s.t('settings.waterServing'),
            subtitle: s.t('settings.waterServingSub'),
            deger: Ayarlar.suPorsiyonMl,
            adim: 50,
            enAz: Ayarlar.sinirlar['suPorsiyon']![0],
            enCok: Ayarlar.sinirlar['suPorsiyon']![1],
            birim: s.t('unit.ml'),
            onChanged: (v) => _yaz(() => Ayarlar.guncelle(suPorsiyonMl: v)),
          ),
          SayiSatiri(
            title: s.t('settings.stepGoal'),
            subtitle: s.t('settings.ringSub'),
            deger: Ayarlar.adimHedefi,
            adim: 500,
            enAz: Ayarlar.sinirlar['adim']![0],
            enCok: Ayarlar.sinirlar['adim']![1],
            birim: s.t('unit.step'),
            onChanged: (v) => _yaz(() => Ayarlar.guncelle(adimHedefi: v)),
          ),
          SayiSatiri(
            title: s.t('settings.calorieGoal'),
            subtitle: s.t('settings.calorieGoalSub'),
            deger: Ayarlar.kaloriHedefi,
            adim: 100,
            enAz: Ayarlar.sinirlar['kalori']![0],
            enCok: Ayarlar.sinirlar['kalori']![1],
            birim: s.t('unit.kcal'),
            onChanged: (v) => _yaz(() => Ayarlar.guncelle(kaloriHedefi: v)),
          ),
          SayiSatiri(
            title: s.t('settings.activeCalorieGoal'),
            subtitle: s.t('settings.activeCalorieGoalSub'),
            deger: Ayarlar.aktifKaloriHedefi,
            adim: 50,
            enAz: Ayarlar.sinirlar['kaloriAktif']![0],
            enCok: Ayarlar.sinirlar['kaloriAktif']![1],
            birim: s.t('unit.kcal'),
            onChanged: (v) =>
                _yaz(() => Ayarlar.guncelle(aktifKaloriHedefi: v)),
          ),
          SayiSatiri(
            title: s.t('settings.distanceGoal'),
            subtitle: s.t('settings.ringSub'),
            deger: Ayarlar.mesafeHedefiOndaKm,
            adim: 5,
            enAz: Ayarlar.sinirlar['mesafeOndaKm']![0],
            enCok: Ayarlar.sinirlar['mesafeOndaKm']![1],
            birim: s.t('unit.km'),
            // Onda bir kilometre tutuluyor: 70 -> 7,0
            bicim: (v) => (v / 10).toStringAsFixed(1),
            onChanged: (v) =>
                _yaz(() => Ayarlar.guncelle(mesafeHedefiOndaKm: v)),
          ),
          NoteBlock(s.t('settings.goalsNote')),

          // ---- hakkında ----
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

/// Başlıkların sağındaki ayar düğmesi. [ScreenHead] içinden çağrılıyor,
/// böylece her ekranın üstünde aynı yerde duruyor ve içerikle birlikte
/// kayıyor.
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
