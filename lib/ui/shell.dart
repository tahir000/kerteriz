import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/ayarlar.dart';
import '../data/day_record.dart';
import '../data/exporter.dart';
import '../data/hatirlatici.dart';
import '../data/health_repository.dart';
import '../data/onbellek.dart';
import '../data/ozet_yazici.dart';
import '../data/regl_kayitlari.dart';
import '../data/tani.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../theme.dart';
import 'coverage_screen.dart';
import 'dongu_ekrani.dart';
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

  /// Ekranda önbellekten gelen veri var ve arka planda tazeleme sürüyor.
  /// Üstteki ince çizgi buna bakıyor.
  bool _tazeleniyor = false;

  /// Okuma nesli. Her yeni okuma bunu artırıyor; uçmakta olan eski bir
  /// okuma sonucunu yazmadan önce neslini kontrol ediyor ve kendi neslini
  /// geçmiş bulursa sessizce çekiliyor.
  ///
  /// Gerekçesi tek bir [HealthRepository] örneği olması: `load()` her
  /// çağrıda kapsama alanlarını sıfırlayıp aynı haritalara yazıyor. İç içe
  /// iki okuma hem o sayıları hem de önbelleği birbirine karıştırırdı.
  int _nesil = 0;

  /// Bir okuma uçuyor mu. Nesil sayacı sonucun yazılmasını engelliyor ama
  /// iki `load()` çağrısının aynı anda aynı depo nesnesine yazmasını
  /// engellemiyor; bu bayrak ikinci okumanın hiç başlamamasını sağlıyor.
  /// Düşen istek kaybolmuyor: ayar değişiminin sayacı kendini erteliyor.
  bool _okumaSuruyor = false;

  /// Tazeleme sürerken Veri sekmesinden tam okuma istendiyse burada
  /// bekliyor; tazeleme biter bitmez çalıştırılıyor. Yoksa düğmeye basmak
  /// sessizce hiçbir şey yapmıyordu.
  bool _bekleyenTam = false;

  @override
  void dispose() {
    Ayarlar.yenidenOku.removeListener(_ayarDegisti);
    Ayarlar.degisti.removeListener(_hedefDegisti);
    Hatirlatici.acilis.removeListener(_bildirimAcildi);
    Ayarlar.yenidenHesapla.removeListener(_yenidenHesapla);
    ReglKayitlari.degisti.removeListener(_yenidenHesapla);
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
      // kalmamalı. Arka plandaki tazeleme de okuma sayılıyor.
      if (_loading || _tazeleniyor) {
        _ayarDegisti();
        return;
      }
      _boot();
    });
  }

  /// Hedef değişti (su, adım, kalori, mesafe). Skorlar bundan etkilenmiyor,
  /// yeniden okumaya gerek yok; ama ana ekran widget'ları hedefi özet
  /// dosyasından okuyor, o dosyanın tazelenmesi lazım.
  /// Döngü sekmesi görünüyor mu ve Veri sekmesinin sırası.
  bool get _donguSekmesi => Ayarlar.donguGorunur(
      veriVar: _allDays.any((d) => d.reglHc));
  int get _veriSekmesi => _donguSekmesi ? 5 : 4;

  /// Regl günü işaretlendi ya da döngü düzeltmesi değişti: Health Connect'i
  /// yeniden okumadan motoru bellekteki günlerle yeniden çalıştır.
  void _yenidenHesapla() {
    if (_allDays.isEmpty) return;
    ReglKayitlari.uygula(_allDays);
    MetricsEngine.run(_allDays, donguDuzeltme: Ayarlar.donguDuzeltme);
    OzetYazici.yaz(_days, allDays: _allDays).catchError((_) {});
    if (mounted) setState(() {});
  }

  void _hedefDegisti() {
    // Cinsiyet değişmiş olabilir: sekmeler yeniden kurulsun.
    if (mounted) {
      setState(() {
        final son = _veriSekmesi;
        if (_tab > son) _tab = son;
      });
    }
    OzetYazici.yaz(_days, allDays: _allDays).catchError((_) {});
    // Kalkış saati ya da hatırlatma tercihi değişmiş olabilir.
    unawaited(Hatirlatici.planla(_days, allDays: _allDays));
  }

  /// Akşam bildirimine dokunuldu: Bugün'e dön, etiket sayfasını aç. Veri
  /// henüz gelmediyse istek bekliyor, ilk çizimde açılıyor.
  bool _bekleyenEtiket = false;

  void _bildirimAcildi() {
    final yuk = Hatirlatici.acilis.value;
    if (yuk == Hatirlatici.sabahYuku) {
      // Sabah bildirimi: Bugün'e dön; sabah sorusu en üstte bekliyor.
      Hatirlatici.acilis.value = null;
      _gitSekme(0);
      return;
    }
    if (yuk != Hatirlatici.etiketYuku) return;
    Hatirlatici.acilis.value = null;
    _bekleyenEtiket = true;
    if (mounted) setState(() {});
  }

  void _etiketSayfasi() {
    _gitSekme(0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: K.bg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EtiketKarti(_allDays.isEmpty ? _days : _allDays,
              ozetli: false),
        ),
      ),
    );
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
    Hatirlatici.acilis.addListener(_bildirimAcildi);
    Ayarlar.yenidenHesapla.addListener(_yenidenHesapla);
    ReglKayitlari.degisti.addListener(_yenidenHesapla);
    unawaited(Hatirlatici.baslat().then((_) => _bildirimAcildi()));
    if (Tani.cokmeIzi != null) {
      _guvenliMod = true;
      _loading = false;
      // Çökme ekranı açıldı: bu açılış başarılı sayılıyor. İzi burada
      // kapatmazsak güvenli mod kendini besliyor (bu oturum da BITTI
      // yazmadan bitiyor) ve üstelik gerçek çökme izinin üstüne bu
      // oturumun üç satırı yazılıyordu.
      unawaited(Tani.bitti());
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

  /// Açılış.
  ///
  /// Hızlı yol: diskteki önbellek. Geçmiş günler bir daha değişmiyor, o
  /// yüzden 90 günün tamamını her açılışta Health Connect'ten okumanın
  /// anlamı yok. Önbellek varsa ekran anında geliyor, tazeleme arkada
  /// yalnızca son birkaç günü okuyor.
  ///
  /// [tam] true ise önbellek atlanır ve 90 gün baştan okunur: Veri
  /// sekmesindeki yeniden okuma düğmesi bunu yapıyor.
  Future<void> _boot({bool tam = false}) async {
    if (_okumaSuruyor) {
      if (tam) _bekleyenTam = true;
      return;
    }
    final nesil = ++_nesil;
    if (!tam) {
      final o = await Onbellek.oku();
      // Dosya okuması asenkron bir boşluk: bu sırada başka bir açılış
      // başlamış olabilir. Bayrak henüz kurulmadığı için tek koruma bu.
      if (nesil != _nesil) return;
      if (o != null && o.gunler.isNotEmpty) {
        await Tani.iz('onbellek: ${o.gunler.length} gun, bosluk ${o.bosluk}');
        ReglKayitlari.uygula(o.gunler);
        MetricsEngine.run(o.gunler, donguDuzeltme: Ayarlar.donguDuzeltme);
        final withData =
            o.gunler.where((d) => d.hasSleep || d.rhr != null).toList();
        _repo.kapsamaYukle(
          sayilar: o.sayilar,
          ilk: o.ilkKayit,
          son: o.sonKayit,
          istenenGun: o.istenenGun,
          zaman: o.tamOkuma,
        );
        if (!mounted) return;
        setState(() {
          _days = withData;
          _allDays = o.gunler;
          _loading = false;
          _errorKey = null;
          _errorDetail = null;
          _tazeleniyor = true;
        });
        // Ekran geldi: açılış izi burada kapanıyor. Tazeleme arkada sürse de
        // uygulama kullanılabilir durumda, güvenli mod tetiklenmemeli.
        await Tani.bitti();
        unawaited(_tazele(o, nesil));
        return;
      }
    }
    await _tamOkuma();
  }

  /// Önbellekten açıldıktan sonra arka planda çalışan tazeleme.
  ///
  /// Yalnızca boşluk kadar günü okuyor. Hata olursa sessizce bırakıyor:
  /// ekranda zaten önbellekten gelen veri duruyor, onu silmek kullanıcıya
  /// bir şey kazandırmaz.
  Future<void> _tazele(OnbellekIcerik o, int nesil) async {
    _okumaSuruyor = true;
    try {
      await _repo.configure().timeout(const Duration(seconds: 15));
      final status =
          await _repo.sdkStatus().timeout(const Duration(seconds: 15));
      if (status != HealthConnectSdkStatus.sdkAvailable) return;

      // İzin kalkmışsa sessiz kalmak tuzak olurdu: ekranda önbellekten
      // gelen eski veri durur, kullanıcı da sebebini hiç öğrenemez.
      // Normal okumaya düşüyoruz, o izni istiyor.
      final izin = await _repo
          .hasPermissions()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (!izin) {
        await Tani.iz('tazeleme: izin yok, tam okumaya dusuluyor');
        await _tamOkuma();
        return;
      }

      // Kapsama tablosu bayatladıysa tazeleme yetmez, hepsini oku.
      if (o.tamOkumaGerek) {
        await Tani.iz('onbellek bayat, tam okuma');
        await _tamOkuma(sessiz: true);
        return;
      }

      // Pencere: en az 3 gün (bileklik geç eşitleyebilir), uygulamayı uzun
      // süre açmadıysan boşluk kadar.
      var pencere = o.bosluk + 2;
      if (pencere < 3) pencere = 3;
      if (pencere > Config.historyDays) pencere = Config.historyDays;
      await Tani.iz('tazeleme: $pencere gun');

      final yeni =
          await _repo.load(days: pencere).timeout(const Duration(seconds: 120));
      if (nesil != _nesil) return; // araya yeni bir okuma girdi
      // Okuma sağlam mı: bir tip zaman aşımına uğradıysa o pencerenin
      // günleri boş iskelet olarak dönüyor. Onları önbellekteki dolu
      // günlerin üstüne yazmak veriyi silmek olur.
      final saglam = _repo.timedOut.isEmpty && _repo.rawCounts.isNotEmpty;
      final sonKayit = _repo.lastPoint;
      if (!saglam) {
        await Tani.iz('tazeleme eksik dondu, onbellek korunuyor');
        _repo.kapsamaYukle(
          sayilar: o.sayilar,
          ilk: o.ilkKayit,
          son: o.sonKayit,
          istenenGun: o.istenenGun,
          zaman: o.tamOkuma,
        );
        return;
      }

      final birlesik = _birlestir(o.gunler, yeni);
      ReglKayitlari.uygula(birlesik);
      MetricsEngine.run(birlesik, donguDuzeltme: Ayarlar.donguDuzeltme);

      // Kapsama tablosu son TAM okumadan geliyor: tazelemenin küçük
      // pencereli sayılarını yazmak "90 günde 12 kayıt" demek olurdu.
      _repo.kapsamaYukle(
        sayilar: o.sayilar,
        ilk: o.ilkKayit,
        son: sonKayit ?? o.sonKayit,
        istenenGun: o.istenenGun,
        zaman: o.tamOkuma,
      );

      final withData =
          birlesik.where((d) => d.hasSleep || d.rhr != null).toList();
      try {
        await OzetYazici.yaz(withData, allDays: birlesik);
      } catch (_) {}
      unawaited(Hatirlatici.planla(withData, allDays: birlesik));

      if (nesil != _nesil) return;
      await Onbellek.yaz(OnbellekIcerik(
        gunler: birlesik,
        sayilar: o.sayilar,
        ilkKayit: o.ilkKayit,
        sonKayit: sonKayit ?? o.sonKayit,
        tamOkuma: o.tamOkuma,
        istenenGun: o.istenenGun,
      ));

      if (!mounted || nesil != _nesil) return;
      setState(() {
        _days = withData;
        _allDays = birlesik;
      });
      await Tani.iz('tazeleme bitti');
    } catch (e) {
      // Kapsama alanları küçük pencereli okumayla doldu; geri yüklenmezse
      // Veri sekmesi 3 günün sayılarını 90 gün diye gösterir.
      _repo.kapsamaYukle(
        sayilar: o.sayilar,
        ilk: o.ilkKayit,
        son: o.sonKayit,
        istenenGun: o.istenenGun,
        zaman: o.tamOkuma,
      );
      await Tani.iz('TAZELEME HATASI: $e');
    } finally {
      _okumaSuruyor = false;
      if (mounted) setState(() => _tazeleniyor = false);
      if (_bekleyenTam) {
        _bekleyenTam = false;
        unawaited(_boot(tam: true));
      }
    }
  }

  /// Okuma başarısız oldu. Sessiz modda ekranda önbellekten gelen veri
  /// duruyor: onu hata ekranıyla değiştirmek kullanıcıya bir şey kazandırmaz,
  /// yalnızca ince çizgiyi kapatıyoruz.
  void _hata(int nesil, bool sessiz, String anahtar, [String? ayrinti]) {
    // Araya yeni bir okuma girdiyse ekran artık onun: eski okumanın hatası
    // taze veriyi hata ekranıyla değiştirmemeli.
    if (!mounted || nesil != _nesil) return;
    setState(() {
      _tazeleniyor = false;
      if (!sessiz) {
        _loading = false;
        _errorKey = anahtar;
        _errorDetail = ayrinti;
      }
    });
  }

  /// Eski günlerin üstüne taze okunanları yazar.
  ///
  /// Taze liste pencere kadar günü kapsıyor ve o günlerin hepsi önbellektekini
  /// geçersiz kılıyor. Pencere dışındaki günler olduğu gibi kalıyor; sonunda
  /// liste [Config.historyDays] gün ile sınırlanıyor.
  List<DayRecord> _birlestir(List<DayRecord> eski, List<DayRecord> yeni) {
    String anahtar(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final harita = {for (final d in eski) anahtar(d.date): d};
    for (final d in yeni) {
      harita[anahtar(d.date)] = d;
    }
    final bugun = DateTime.now();
    final sinir = DateTime(bugun.year, bugun.month, bugun.day - Config.historyDays);
    final liste = harita.values.where((d) => !d.date.isBefore(sinir)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return liste;
  }

  /// Health Connect'ten 90 günün tamamını okuyan yol.
  ///
  /// [sessiz] true ise ekranda zaten önbellekten gelen veri var: yükleme
  /// ekranına dönmüyoruz ve hata olursa ekranı bozmuyoruz.
  Future<void> _tamOkuma({bool sessiz = false}) async {
    final nesil = ++_nesil;
    _okumaSuruyor = true;
    if (!mounted) {
      _okumaSuruyor = false;
      return;
    }
    setState(() {
      if (!sessiz) {
        _loading = true;
        _errorKey = null;
        _errorDetail = null;
      }
      _tazeleniyor = sessiz;
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
        _hata(nesil, sessiz, 'state.noSdk');
        return;
      }
      if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _repo.installHealthConnect();
        _hata(nesil, sessiz, 'state.updateSdk');
        return;
      }

      await Tani.iz('izin kontrolu');
      var ok = await _repo
          .hasPermissions()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      // İzin isteğine zaman aşımı koymuyoruz: ekranda kullanıcı bekliyor.
      // Sessiz okumada hiç istemiyoruz: arka planda izin ekranı açmak kaba.
      if (!ok && !sessiz) {
        await Tani.iz('izin istegi');
        ok = await _repo.requestPermissions();
      }
      await Tani.iz('izin = $ok');
      if (!ok) {
        _hata(nesil, sessiz, 'state.noPermission');
        return;
      }
      // Sonradan eklenen isteğe bağlı izinler (antrenmanlar) bir kez sorulsun.
      if (!sessiz) {
        await Tani.iz('istege bagli izinler');
        await _repo.yeniIzinleriSor();
      }

      await Tani.iz('okuma basliyor');
      final days =
          await _repo.load().timeout(const Duration(seconds: 180));
      await Tani.iz('motor basliyor, gun: ${days.length}');
      ReglKayitlari.uygula(days);
      MetricsEngine.run(days, donguDuzeltme: Ayarlar.donguDuzeltme);
      await Tani.iz('motor bitti');
      final withData = days.where((d) => d.hasSleep || d.rhr != null).toList();
      // Ana ekran özet widget'ının okuyacağı dosya. Başarısız olursa
      // yalnızca widget eksik kalır, uygulama normal çalışır.
      try {
        await OzetYazici.yaz(withData, allDays: days);
      } catch (_) {}
      unawaited(Hatirlatici.planla(withData, allDays: days));
      await Tani.iz('ozet yazildi');

      // Önbellek: bir sonraki açılış bu dosyadan gelecek. Hiç kayıt
      // dönmediyse yazmıyoruz: `load()` hata yutup boş iskelet günlerle
      // başarıyla dönebiliyor ve onu yazmak, kullanıcıyı bir sonraki tam
      // okumaya kadar boş bir uygulamayla bırakmak olur.
      //
      // Zaman aşımına uğramış tipe takılmıyoruz: bazı cihazlarda bir tip
      // her seferinde zaman aşımına uğruyor ve o yüzden önbelleği hiç
      // yazmamak, hızlanmadan tamamen vazgeçmek demek olurdu.
      final saglam = _repo.rawCounts.isNotEmpty;
      if (nesil != _nesil) return;
      if (saglam) {
        await Onbellek.yaz(OnbellekIcerik(
          gunler: days,
          sayilar: _repo.kapsamaAdlari,
          ilkKayit: _repo.firstPoint,
          sonKayit: _repo.lastPoint,
          tamOkuma: DateTime.now(),
          istenenGun: _repo.requestedDays,
        ));
        await Tani.iz('onbellek yazildi');
      } else {
        await Tani.iz('okuma bos dondu, onbellek yazilmadi');
      }

      final thin = withData.length < 3;
      if (!mounted) return;
      // Sessiz okuma boş döndü: ekranda önbellekten gelen dolu veri var,
      // onu boş iskeletlerle değiştirmek kullanıcıyı sebepsiz yere boş
      // ekrana düşürür. Disk önbelleği zaten yukarıda korundu.
      if (!saglam && sessiz) {
        setState(() => _tazeleniyor = false);
        return;
      }
      setState(() {
        // Uyku ya da nabız kaydı olmayan günlerle skor ekranı çizilmez.
        // Eskiden boş listede bütün günlere düşülüyordu ve hazırlık "0 düşük"
        // görünüyordu: bu bir skor değil, hesaplanamamış demekti.
        _days = withData;
        _allDays = days;
        _loading = false;
        _tazeleniyor = false;
        // Veri henüz azken skor ekranlarını açmak yanıltıcı olur;
        // önce Health Connect'ten ne geldiğini göster. Sessiz okumada
        // sekmeyi değiştirmiyoruz: kullanıcı o sırada bir yere bakıyor.
        if (thin && !sessiz) _tab = _veriSekmesi;
      });
      // PageView henüz kurulmadığı için doğrudan atlayamıyoruz; ilk
      // çerçeveden sonra sayfa da doğru yere gidiyor.
      if (thin && !sessiz) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pc.hasClients) _pc.jumpToPage(_veriSekmesi);
        });
      }
      await Tani.bitti();
    } catch (e) {
      await Tani.iz('BOOT HATASI: $e');
      _hata(nesil, sessiz, 'state.readError', '$e');
    } finally {
      _okumaSuruyor = false;
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
              onPressed: () => _gitSekme(_veriSekmesi),
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
        if (_donguSekmesi) _skorYok(s),
        CoverageScreen(
            repo: _repo, days: _allDays, onReload: () => _boot(tam: true)),
      ]);
    } else {
      if (_bekleyenEtiket) {
        _bekleyenEtiket = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _etiketSayfasi();
        });
      }
      body = _sayfalar([
        TodayScreen(_days,
            allDays: _allDays,
            kalpKaynagi: _repo.kaynaklar['HEART_RATE']?.firstOrNull),
        SleepScreen(_days),
        LoadScreen(_days),
        HeartScreen(_days),
        if (_donguSekmesi) DonguEkrani(days: _allDays),
        // Tanı ekranı filtrelenmemiş listeyi görmeli: uyku ya da nabız
        // olmayan bir günde solunum veya SpO2 gelmiş olabilir.
        CoverageScreen(
            repo: _repo, days: _allDays, onReload: () => _boot(tam: true)),
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

    final sekmeler = <(IconData, String)>[
      (Icons.circle_outlined, s.t('tab.today')),
      (Icons.nightlight_outlined, s.t('tab.sleep')),
      (Icons.show_chart, s.t('tab.load')),
      (Icons.favorite_outline, s.t('tab.heart')),
      if (_donguSekmesi) (Icons.water_drop_outlined, s.t('tab.cycle')),
      (Icons.storage_outlined, s.t('tab.data')),
    ];
    final baslik = sekmeler[_tab.clamp(0, sekmeler.length - 1)].$2;

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
          // Arka planda tazeleme sürerken üstte ince bir çizgi. Metin yok:
          // ekranda zaten veri var, bu yalnızca "daha yenisi geliyor" demek.
          if (_tazeleniyor)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: K.accent,
                ),
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
        ogeler: sekmeler,
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
