import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:share_plus/share_plus.dart';

import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../data/exporter.dart';
import '../data/health_repository.dart';
import '../data/ozet_yazici.dart';
import '../data/tani.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../theme.dart';
import 'coverage_screen.dart';
import 'screens.dart';
import 'widgets/marka.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _repo = HealthRepository();
  int _tab = 0;
  bool _loading = true;
  String? _errorKey;
  String? _errorDetail;
  List<DayRecord> _days = [];

  /// Filtrelenmemiş, takvim günü boşluksuz liste — hidrasyon karşılaştırması
  /// ardışık günlere dayandığı için bu listeyi kullanır.
  List<DayRecord> _allDays = [];

  /// Önceki açılış yarıda kaldıysa güvenli moddayız: Health Connect'e hiç
  /// dokunmadan izi gösteriyoruz. Kullanıcı isterse yine de deneyebilir.
  bool _guvenliMod = false;

  /// Kaydırma miktarı: üst çubuğun belirmesi buna bağlı.
  double _kaydirma = 0;

  /// Sekmeler arası parmakla geçiş. Sayfa sırası alt menüyle aynı.
  final PageController _pc = PageController();

  /// Ayar değişiminden sonra yeniden okumayı geciktiren sayaç.
  Timer? _ayarZaman;

  @override
  void dispose() {
    Ayarlar.yenidenOku.removeListener(_ayarDegisti);
    Ayarlar.degisti.removeListener(_hedefDegisti);
    _ayarZaman?.cancel();
    _pc.dispose();
    super.dispose();
  }

  /// Yaş değişti: nabız bölgeleri ve günlük yük ona bağlı, veri yeniden
  /// işlenmeli. Ayarlar ekranı açıkken de çalışıyor, kullanıcı geri
  /// döndüğünde sayılar güncel oluyor.
  ///
  /// Gecikme şart: yaşı artı düğmesiyle beş kez artıran biri beş okuma
  /// başlatırdı. Son dokunuştan bir saniye sonra tek bir okuma yapılıyor.
  void _ayarDegisti() {
    _ayarZaman?.cancel();
    _ayarZaman = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      // Okuma sürüyorsa iptal etmek yerine erteliyoruz: ilk açılışta yaşını
      // düzelten biri, okuma bitince eski hrMax ile hesaplanmış sayılarla
      // kalmamalı.
      if (_loading) {
        _ayarDegisti();
        return;
      }
      _boot();
    });
  }

  /// Hedef değişti (su, adım, kalori, mesafe). Skorlar bundan etkilenmiyor,
  /// yeniden okumaya gerek yok; ama ana ekran widget'ları hedefi özet
  /// dosyasından okuyor, o dosyanın tazelenmesi lazım.
  void _hedefDegisti() {
    OzetYazici.yaz(_days).catchError((_) {});
  }

  /// Alt menüden ya da ekran içindeki bir düğmeden sekme değiştirme.
  /// Sayfa kaydırmayla geldiği için geçişin yönü kendiliğinden doğru.
  void _gitSekme(int i) {
    if (_pc.hasClients) {
      _pc.animateToPage(i,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  void initState() {
    super.initState();
    Ayarlar.yenidenOku.addListener(_ayarDegisti);
    Ayarlar.degisti.addListener(_hedefDegisti);
    if (Tani.cokmeIzi != null) {
      _guvenliMod = true;
      _loading = false;
    } else {
      _boot();
    }
  }

  /// Çökme izi ekranı. Uygulama bir önceki açılışta ölmüşse ilk bu çıkar;
  /// böylece en azından açılır ve nerede öldüğü okunabilir.
  Widget _cokmeEkrani(S s) {
    final iz = Tani.cokmeIzi ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(K.gutter, 40, K.gutter, 40),
      children: [
        Text(s.t('crash.eyebrow').toUpperCase(), style: K.eyebrow),
        const SizedBox(height: 10),
        Text(s.t('crash.title'), style: K.title),
        const SizedBox(height: 14),
        Text(s.t('crash.body'), style: K.caption),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: K.fill, borderRadius: BorderRadius.circular(10)),
          child: SelectableText(
            iz.isEmpty ? '-' : iz,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11.5, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: BorderSide(color: K.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(K.rDugme))),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: iz));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.t('crash.copied'))));
              },
              child: Text(s.t('crash.copy')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: BorderSide(color: K.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(K.rDugme))),
              onPressed: () async {
                try {
                  await SharePlus.instance
                      .share(ShareParams(text: iz, subject: 'Kerteriz iz'));
                } catch (_) {}
              },
              child: Text(s.t('crash.share')),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            await Tani.temizle();
            if (!mounted) return;
            setState(() => _guvenliMod = false);
            _boot();
          },
          child: Text(s.t('crash.retry')),
        ),
      ],
    );
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _errorDetail = null;
    });
    try {
      // Platform çağrılarının hepsinde zaman aşımı var: biri yanıt vermezse
      // açılış ekranı donup kalmasın, hata ekranına düşsün.
      await Tani.iz('configure');
      await _repo.configure().timeout(const Duration(seconds: 15));
      await Tani.iz('sdkStatus');
      final status =
          await _repo.sdkStatus().timeout(const Duration(seconds: 15));
      await Tani.iz('sdkStatus = $status');
      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        setState(() {
          _loading = false;
          _errorKey = 'state.noSdk';
        });
        return;
      }
      if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _repo.installHealthConnect();
        setState(() {
          _loading = false;
          _errorKey = 'state.updateSdk';
        });
        return;
      }

      await Tani.iz('izin kontrolu');
      var ok = await _repo
          .hasPermissions()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      // İzin isteğine zaman aşımı koymuyoruz: ekranda kullanıcı bekliyor.
      if (!ok) {
        await Tani.iz('izin istegi');
        ok = await _repo.requestPermissions();
      }
      await Tani.iz('izin = $ok');
      if (!ok) {
        setState(() {
          _loading = false;
          _errorKey = 'state.noPermission';
        });
        return;
      }

      await Tani.iz('okuma basliyor');
      final days =
          await _repo.load().timeout(const Duration(seconds: 180));
      await Tani.iz('motor basliyor, gun: ${days.length}');
      MetricsEngine.run(days);
      await Tani.iz('motor bitti');
      final withData = days.where((d) => d.hasSleep || d.rhr != null).toList();
      // Ana ekran özet widget'ının okuyacağı dosya. Başarısız olursa
      // yalnızca widget eksik kalır, uygulama normal çalışır.
      try {
        await OzetYazici.yaz(withData);
      } catch (_) {}
      await Tani.iz('ozet yazildi');
      final thin = withData.length < 3;
      setState(() {
        // Uyku ya da nabız kaydı olmayan günlerle skor ekranı çizilmez.
        // Eskiden boş listede bütün günlere düşülüyordu ve hazırlık "0 düşük"
        // görünüyordu: bu bir skor değil, hesaplanamamış demekti.
        _days = withData;
        _allDays = days;
        _loading = false;
        // Veri henüz azken skor ekranlarını açmak yanıltıcı olur;
        // önce Health Connect'ten ne geldiğini göster.
        if (thin) _tab = 4;
      });
      // PageView henüz kurulmadığı için doğrudan atlayamıyoruz; ilk
      // çerçeveden sonra sayfa da doğru yere gidiyor.
      if (thin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pc.hasClients) _pc.jumpToPage(4);
        });
      }
      await Tani.bitti();
    } catch (e) {
      await Tani.iz('BOOT HATASI: $e');
      setState(() {
        _loading = false;
        _errorKey = 'state.readError';
        _errorDetail = '$e';
      });
    }
  }

  /// Sekme sayfaları. Parmakla yatay kaydırma ve alt menü aynı denetleyiciyi
  /// paylaşıyor: hangisiyle geçilirse geçilsin öteki de takip ediyor.
  ///
  /// IndexedStack'ten PageView'a geçmenin bedeli, komşu olmayan sayfaların
  /// bellekte tutulmaması. Ekranlar zaten durumsuz ve veriden kuruluyor,
  /// kaydırma konumu da [PageStorageKey] ile saklanıyor.
  Widget _sayfalar(List<Widget> cocuklar) => PageView(
        controller: _pc,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() {
          _tab = i;
          // Yeni sekme en üstten başlıyor; eski sekmenin kaydırma
          // konumuyla üst çubuğu açık bırakmayalım.
          _kaydirma = 0;
        }),
        children: [
          for (var i = 0; i < cocuklar.length; i++)
            KeyedSubtree(
                key: PageStorageKey<String>('sekme$i'), child: cocuklar[i]),
        ],
      );

  /// Gün kaydı var ama içinde uyku ya da nabız yok: skor ekranlarının
  /// yerine geçen durum. Sıfır göstermek yanıltıcı olurdu.
  Widget _skorYok(S s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.t('state.noScores'),
                style: K.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: BorderSide(color: K.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(K.rDugme))),
              onPressed: () => _gitSekme(4),
              child: Text(s.t('data.title')),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _boot, child: Text(s.t('common.retry'))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget body;

    if (_guvenliMod) {
      body = _cokmeEkrani(s);
    } else if (_loading) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: KerterizYukleniyor(s.t('state.reading')),
      );
    } else if (_errorKey != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.t(_errorKey!), style: K.caption, textAlign: TextAlign.center),
            if (_errorDetail != null) ...[
              const SizedBox(height: 8),
              Text(_errorDetail!,
                  style: TextStyle(fontSize: 12, color: K.ink3),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: BorderSide(color: K.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(K.rDugme))),
              onPressed: _boot,
              child: Text(s.t('common.retry')),
            ),
          ]),
        ),
      );
    } else if (_allDays.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.t('state.noRecords'),
                style: K.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(onPressed: _boot, child: Text(s.t('common.retry'))),
          ]),
        ),
      );
    } else if (_days.isEmpty) {
      // Health Connect'ten gün geldi ama hiçbirinde uyku ya da nabız yok.
      // Skor ekranları bu ikisine dayanıyor; sıfır göstermek yerine durumu
      // söylüyoruz. Veri sekmesi yine çalışıyor, tanı oradan yapılır.
      body = _sayfalar([
        _skorYok(s),
        _skorYok(s),
        _skorYok(s),
        _skorYok(s),
        CoverageScreen(repo: _repo, days: _allDays, onReload: _boot),
      ]);
    } else {
      body = _sayfalar([
        TodayScreen(_days, allDays: _allDays),
        SleepScreen(_days),
        LoadScreen(_days),
        HeartScreen(_days),
        // Tanı ekranı filtrelenmemiş listeyi görmeli: uyku ya da nabız
        // olmayan bir günde solunum veya SpO2 gelmiş olabilir.
        CoverageScreen(repo: _repo, days: _allDays, onReload: _boot),
      ]);
    }

    // Gövdenin hangi durumu gösterdiği. Yalnızca bu değişince açılma
    // animasyonu oynuyor.
    final durum = _guvenliMod
        ? 'guvenli'
        : _loading
            ? 'yukleniyor'
            : _errorKey != null
                ? 'hata'
                : 'icerik';

    final baslik = [
      s.t('tab.today'),
      s.t('tab.sleep'),
      s.t('tab.load'),
      s.t('tab.heart'),
      s.t('tab.data'),
    ][_tab.clamp(0, 4)];

    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          // Sekmeler arası geçiş artık sayfa kaydırmanın kendisi; burada
          // yalnızca yükleme ile içerik arasındaki açılma var.
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis != Axis.vertical) return false;
              final p = n.metrics.pixels;
              // Yalnızca eşiğin iki yanında geçiş olduğunda yeniden çiz.
              final eski = _kaydirma > 46;
              final yeni = p > 46;
              if (eski != yeni) setState(() => _kaydirma = p);
              return false;
            },
            // Yükleme bitip içerik gelirken kısa bir açılma: simge yerini
            // ekrana bırakıyor. Sekme değişimi bu anahtarı değiştirmediği
            // için sayfalar yeniden kurulmuyor.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.965, end: 1.0)
                      .animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey<String>(durum), child: body),
            ),
          ),
          // Kaydırınca beliren kompakt üst çubuk: derinlik hissi ve bağlam.
          if (!_guvenliMod && !_loading && _errorKey == null)
            // Konumlandırılmamış bir Stack çocuğu gevşek kısıtla ölçülür ve
            // metnin genişliği kadar kalır; çubuğun ekranı kaplaması için
            // sol ve sağ sabitlenmeli.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _kaydirma > 46 ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: K.bg.withValues(alpha: 0.94),
                      boxShadow: K.cubukGolge,
                    ),
                    child: Text(baslik, style: K.titleSmall),
                  ),
                ),
              ),
            ),
        ]),
      ),
      floatingActionButton: _allDays.isEmpty
          ? null
          : FloatingActionButton.small(
              backgroundColor: K.ink,
              // Koyu temada K.ink neredeyse beyaz: simge rengi de zeminle
              // birlikte dönmeli, yoksa beyaz üstünde beyaz kalıyor.
              foregroundColor: K.card,
              elevation: 2,
              tooltip: s.t('data.export'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final failed = s.t('data.exportFailed');
                try {
                  await Exporter.share(_days.isEmpty ? _allDays : _days,
                      subject: s.t('data.exportSubject'));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('$failed: $e')));
                }
              },
              child: const Icon(Icons.ios_share, size: 18),
            ),
      bottomNavigationBar: _AltMenu(
        secili: _tab,
        onSec: _gitSekme,
        ogeler: [
          (Icons.circle_outlined, s.t('tab.today')),
          (Icons.nightlight_outlined, s.t('tab.sleep')),
          (Icons.show_chart, s.t('tab.load')),
          (Icons.favorite_outline, s.t('tab.heart')),
          (Icons.storage_outlined, s.t('tab.data')),
        ],
      ),
    );
  }
}

/// Alt gezinme çubuğu.
///
/// `NavigationBar` yerine elde yazıldı: seçili simgenin altına kayan kapsül
/// koymak ve dokunuşta simgeyi zıplatmak Material'in kendi göstergesiyle
/// mümkün değildi.
class _AltMenu extends StatelessWidget {
  final int secili;
  final ValueChanged<int> onSec;
  final List<(IconData, String)> ogeler;

  const _AltMenu(
      {required this.secili, required this.onSec, required this.ogeler});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: K.card,
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              for (var i = 0; i < ogeler.length; i++)
                Expanded(
                  child: _AltDugme(
                    ikon: ogeler[i].$1,
                    etiket: ogeler[i].$2,
                    secili: i == secili,
                    onTap: () => onSec(i),
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// Tek bir menü düğmesi.
///
/// Zıplama hem dokunuşta hem de sayfa kaydırılarak buraya gelindiğinde
/// oynuyor: [didUpdateWidget] seçili olma anını yakalıyor, böylece parmakla
/// geçerken de simge canlanıyor.
class _AltDugme extends StatefulWidget {
  final IconData ikon;
  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  const _AltDugme({
    required this.ikon,
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  @override
  State<_AltDugme> createState() => _AltDugmeState();
}

class _AltDugmeState extends State<_AltDugme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant _AltDugme old) {
    super.didUpdateWidget(old);
    if (!old.secili && widget.secili) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dokun() {
    _c.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final renk = widget.secili ? K.ink : K.ink3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dokun,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Seçili simgenin altındaki kapsül: hangi sekmede olduğumuz
          // yalnızca renkle değil, biçimle de belli olsun.
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: widget.secili ? 42 : 32,
            height: 28,
            decoration: BoxDecoration(
              color: widget.secili ? K.fill : Colors.transparent,
              borderRadius: BorderRadius.circular(K.kapsul),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, cocuk) {
                // Yarım sinüs: 1'den çıkıp tepeye gidiyor ve 1'e dönüyor.
                final v = Curves.easeOut.transform(_c.value);
                final olcek = 1 + 0.22 * math.sin(math.pi * v);
                return Transform.scale(
                  scale: olcek,
                  child: Transform.translate(
                    offset: Offset(0, -2 * math.sin(math.pi * v)),
                    child: cocuk,
                  ),
                );
              },
              child: Icon(widget.ikon, size: 21, color: renk),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 260),
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: widget.secili ? FontWeight.w600 : FontWeight.w500,
              color: renk,
            ),
            child: Text(widget.etiket),
          ),
        ],
      ),
    );
  }
}
