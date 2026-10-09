import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../theme.dart';

/// Kullanıcının uygulama içi seçimlerini tutan küçük dosya.
///
/// `shared_preferences` yerine düz JSON: projede zaten `path_provider` var,
/// yeni bir paket eklemeye değmiyor. Dosya [OzetYazici] ile aynı klasörde
/// (Android'de `context.filesDir`) durur.
///
/// [Config] artık bu değerlerin **varsayılanı**; kullanıcının seçtiği değer
/// buradadır. Kişisel bir yapıda ikisi aynıydı, mağazadan kurulan bir
/// uygulamada olamaz: yaş nabız bölgelerinin tamamını belirliyor.
class Ayarlar {
  static const String dosyaAdi = 'kerteriz_ayarlar.json';

  // ---- tema ----
  static final ValueNotifier<TemaTercihi> tema =
      ValueNotifier<TemaTercihi>(TemaTercihi.sistem);

  // ---- sayısal tercihler ----
  static int yas = Config.age;
  static int suHedefiMl = Config.dailyWaterGoalMl;
  static int suPorsiyonMl = Config.waterServingMl;
  static int adimHedefi = Config.dailyStepGoal;
  static int kaloriHedefi = Config.dailyCalorieGoal;
  static int aktifKaloriHedefi = Config.dailyActiveCalorieGoal;
  static int mesafeHedefiOndaKm = Config.dailyDistanceTenthKm;

  /// Hedef kalkış saati, gece yarısından itibaren dakika. Yatma saati
  /// önerisi buna göre geri sayıyor.
  static int kalkisDk = Config.wakeMinute;

  /// Akşam hatırlatması: yatma saatinden yarım saat önce bildirim.
  /// Varsayılan kapalı; açarken bildirim izni isteniyor.
  static bool hatirlatma = false;

  /// Sabah bildirimi: kalkış saatinden yarım saat sonra, hazırlığa ve sabah
  /// sorusuna davet. Varsayılan kapalı.
  static bool sabahBildirimi = false;

  /// Bir kez sorulmuş isteğe bağlı Health Connect izinleri (tip adları).
  /// Reddedilen izin her açılışta yeniden sorulmasın diye tutuluyor.
  static final Set<String> sorulanIzinler = {};

  /// Cinsiyet: 'kadin', 'erkek' ya da null (belirtilmedi). Yalnızca arayüz
  /// için: "kadin" seçilince Döngü sekmesi ve ayarlardaki döngü bölümü
  /// açılıyor, regl izni isteniyor. Hiçbir hesaba girmiyor ve hiçbir yere
  /// gönderilmiyor.
  static String? cinsiyet;

  /// Hazırlığı döngü evresine göre düzelt (yalnızca yeterli döngü verisi varsa).
  static bool donguDuzeltme = true;

  /// Veriyi Health Connect'ten yeniden okumadan motoru yeniden çalıştırma
  /// isteği: regl günü işaretlendi ya da döngü düzeltmesi açılıp kapandı.
  static final ValueNotifier<int> yenidenHesapla = ValueNotifier<int>(0);

  /// Döngü arayüzü görünsün mü: kadın seçildiyse ya da cinsiyet
  /// belirtilmemiş ama regl kaydı geliyorsa.
  static bool donguGorunur({bool veriVar = false}) =>
      cinsiyet == 'kadin' || (cinsiyet == null && veriVar);

  /// "Cihazın HRV paylaşmıyor" notu kapatıldı mı.
  static bool cihazNotuKapali = false;

  /// Tanaka formülü. Nabız bölgeleri ve dolayısıyla günlük yük buna bağlı.
  static double get hrMax => 208 - 0.7 * yas;

  /// Herhangi bir sayısal tercih değiştiğinde artar. [Shell] dinliyor ve
  /// widget'ların okuduğu özet dosyasını tazeliyor: hedefler oraya yazılıyor.
  static final ValueNotifier<int> degisti = ValueNotifier<int>(0);

  /// Yalnızca veriyi yeniden işlemeyi gerektiren değişikliklerde artar
  /// (şimdilik yaş). [Shell] dinliyor ve okumayı baştan başlatıyor.
  static final ValueNotifier<int> yenidenOku = ValueNotifier<int>(0);

  /// Sınırlar: elde girilen bir sayı formülleri saçmalatmasın.
  static const Map<String, List<int>> sinirlar = {
    'yas': [10, 100],
    'su': [500, 6000],
    'suPorsiyon': [50, 1000],
    'adim': [1000, 60000],
    'kalori': [800, 8000],
    'kaloriAktif': [100, 4000],
    'mesafeOndaKm': [5, 600],
    'kalkis': [240, 720],
  };

  static int _kis(String alan, int deger) {
    final s = sinirlar[alan]!;
    return deger < s[0] ? s[0] : (deger > s[1] ? s[1] : deger);
  }

  static Future<File> _dosya() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
  }

  /// Açılışta bir kez çağrılır. Dosya yoksa ya da bozuksa varsayılanla
  /// devam eder: ayar okunamaması uygulamayı durdurmaz.
  static Future<void> oku() async {
    try {
      final f = await _dosya();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map) return;

      final ad = m['tema'];
      if (ad is String) {
        tema.value = TemaTercihi.values.firstWhere(
          (t) => t.name == ad,
          orElse: () => TemaTercihi.sistem,
        );
      }

      int al(String alan, int simdiki) {
        final v = m[alan];
        return v is int ? _kis(alan, v) : simdiki;
      }

      yas = al('yas', yas);
      suHedefiMl = al('su', suHedefiMl);
      suPorsiyonMl = al('suPorsiyon', suPorsiyonMl);
      adimHedefi = al('adim', adimHedefi);
      kaloriHedefi = al('kalori', kaloriHedefi);
      aktifKaloriHedefi = al('kaloriAktif', aktifKaloriHedefi);
      mesafeHedefiOndaKm = al('mesafeOndaKm', mesafeHedefiOndaKm);
      kalkisDk = al('kalkis', kalkisDk);
      if (m['hatirlatma'] is bool) hatirlatma = m['hatirlatma'] as bool;
      if (m['sabah'] is bool) sabahBildirimi = m['sabah'] as bool;
      final c = m['cinsiyet'];
      if (c == 'kadin' || c == 'erkek') cinsiyet = c as String;
      if (m['donguDuzeltme'] is bool) donguDuzeltme = m['donguDuzeltme'] as bool;
      if (m['cihazNotuKapali'] is bool) cihazNotuKapali = m['cihazNotuKapali'] as bool;
      final si = m['sorulanIzinler'];
      if (si is List) sorulanIzinler.addAll(si.whereType<String>());
    } catch (_) {
      // Bozuk dosya: varsayılanla devam.
    }
  }

  /// Seçimi hem bellekte hem diske yazar. Bellek önce güncelleniyor ki
  /// arayüz diski beklemeden değişsin.
  static Future<void> temaYaz(TemaTercihi t) async {
    tema.value = t;
    await _kaydet();
  }

  /// Verilen alanları günceller, sınırlara kırpar ve diske yazar.
  /// Yaş değişmişse ayrıca yeniden okuma isteği yayınlanır: nabız bölgeleri
  /// yaşa bağlı, eski hesapla kalmamalı.
  static Future<void> guncelle({
    int? yas,
    int? suHedefiMl,
    int? suPorsiyonMl,
    int? adimHedefi,
    int? kaloriHedefi,
    int? aktifKaloriHedefi,
    int? mesafeHedefiOndaKm,
    int? kalkisDk,
  }) async {
    final yasDegisti = yas != null && _kis('yas', yas) != Ayarlar.yas;

    if (yas != null) Ayarlar.yas = _kis('yas', yas);
    if (suHedefiMl != null) Ayarlar.suHedefiMl = _kis('su', suHedefiMl);
    if (suPorsiyonMl != null) {
      Ayarlar.suPorsiyonMl = _kis('suPorsiyon', suPorsiyonMl);
    }
    if (adimHedefi != null) Ayarlar.adimHedefi = _kis('adim', adimHedefi);
    if (kaloriHedefi != null) {
      Ayarlar.kaloriHedefi = _kis('kalori', kaloriHedefi);
    }
    if (aktifKaloriHedefi != null) {
      Ayarlar.aktifKaloriHedefi = _kis('kaloriAktif', aktifKaloriHedefi);
    }
    if (mesafeHedefiOndaKm != null) {
      Ayarlar.mesafeHedefiOndaKm = _kis('mesafeOndaKm', mesafeHedefiOndaKm);
    }
    if (kalkisDk != null) Ayarlar.kalkisDk = _kis('kalkis', kalkisDk);

    degisti.value++;
    await _kaydet();
    if (yasDegisti) yenidenOku.value++;
  }

  /// Akşam hatırlatmasını açar ya da kapatır. Zamanlama [Hatirlatici]
  /// tarafında; burası yalnızca tercihi tutuyor ve dinleyenlere haber veriyor.
  static Future<void> hatirlatmaYaz(bool acik) async {
    hatirlatma = acik;
    degisti.value++;
    await _kaydet();
  }

  static Future<void> cinsiyetYaz(String? c) async {
    cinsiyet = c;
    degisti.value++;
    await _kaydet();
  }

  static Future<void> donguDuzeltmeYaz(bool acik) async {
    donguDuzeltme = acik;
    degisti.value++;
    yenidenHesapla.value++;
    await _kaydet();
  }

  static Future<void> cihazNotunuKapat() async {
    cihazNotuKapali = true;
    degisti.value++;
    await _kaydet();
  }

  static Future<void> izinSoruldu(Iterable<String> adlar) async {
    sorulanIzinler.addAll(adlar);
    await _kaydet();
  }

  static Future<void> sabahYaz(bool acik) async {
    sabahBildirimi = acik;
    degisti.value++;
    await _kaydet();
  }

  /// Yazma sırası. Her basış bir dosya yazımı başlatıyor; iki yazım aynı
  /// anda çalışırsa ikisi de dosyayı baştan kırpıp yazar ve uzun olan sonra
  /// bitince dosyanın kuyruğunda artık baytlar kalır. Bozuk JSON'u [oku]
  /// sessizce yutuyor, kullanıcı da "ayarlarım sıfırlandı" diyor.
  static Future<void> _sira = Future<void>.value();

  static Future<void> _kaydet() =>
      _sira = _sira.then((_) => _diskeYaz()).catchError((_) {});

  static Future<void> _diskeYaz() async {
    try {
      final f = await _dosya();
      await f.writeAsString(jsonEncode({
        'schema': 2,
        'tema': tema.value.name,
        'yas': yas,
        'su': suHedefiMl,
        'suPorsiyon': suPorsiyonMl,
        'adim': adimHedefi,
        'kalori': kaloriHedefi,
        'kaloriAktif': aktifKaloriHedefi,
        'mesafeOndaKm': mesafeHedefiOndaKm,
        'kalkis': kalkisDk,
        'hatirlatma': hatirlatma,
        'sabah': sabahBildirimi,
        'sorulanIzinler': sorulanIzinler.toList()..sort(),
        'cihazNotuKapali': cihazNotuKapali,
        'cinsiyet': cinsiyet,
        'donguDuzeltme': donguDuzeltme,
      }));
    } catch (_) {
      // Yazılamadıysa seçim bu oturum boyunca geçerli kalır.
    }
  }
}
