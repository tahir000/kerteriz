import 'dart:async';
import 'dart:typed_data';

import 'package:health/health.dart';

import '../config.dart';
import 'ayarlar.dart';
import 'day_record.dart';
import 'uyku_bloklari.dart';
import 'tani.dart';

/// Health Connect'ten okuyup günlük kayıtlara çeviren katman.
/// Hiçbir yere veri göndermez; her şey cihazda kalır.
class HealthRepository {
  final Health _health = Health();

  /// Yanıt vermeyen tipler. Health Connect bazen bir tipte hiç dönmüyor;
  /// zaman aşımına uğrayanları burada tutuyoruz ki okuma sonsuza kadar
  /// beklemesin ve sebebi görünür olsun.
  final List<HealthDataType> timedOut = [];

  /// Son okumada Health Connect'in tip tip kaç kayıt döndürdüğü.
  /// Boş dönen bir tip, izin verilmiş olsa bile o verinin hiç yazılmadığını gösterir.
  Map<HealthDataType, int> rawCounts = {};
  DateTime? firstPoint;
  DateTime? lastPoint;
  int requestedDays = 0;

  /// Kapsama sayılarının ne zamanki **tam** okumadan geldiği. Önbellekten
  /// gelen bir oturumda bu geçmiş bir tarih olur; Veri sekmesi onu yazıyor
  /// ki tablo bayatken sayılara olduğundan fazla güvenilmesin.
  DateTime? kapsamaZamani;

  /// Önbellekten gelen kapsama bilgisini geri yükler.
  ///
  /// Tazeleme okuması yalnızca son birkaç günü kapsıyor; onun sayılarını
  /// tabloya yazmak "90 günde 12 uyku kaydı var" demek olurdu. Bu yüzden
  /// tablo son tam okumanın sayılarını gösteriyor.
  void kapsamaYukle({
    required Map<String, int> sayilar,
    DateTime? ilk,
    DateTime? son,
    required int istenenGun,
    required DateTime zaman,
  }) {
    final adlar = {for (final t in HealthDataType.values) t.name: t};
    rawCounts = {};
    sayilar.forEach((ad, adet) {
      final t = adlar[ad];
      if (t != null) rawCounts[t] = adet;
    });
    firstPoint = ilk;
    lastPoint = son;
    requestedDays = istenenGun;
    kapsamaZamani = zaman;
  }

  /// Kapsama sayılarını ada göre verir: önbelleğe böyle yazılıyor.
  Map<String, int> get kapsamaAdlari =>
      {for (final e in rawCounts.entries) e.key.name: e.value};

  /// Okumak istediğimiz tipler. Cihaz ya da Google Health bir tipi
  /// yazmıyorsa o tip boş döner; uygulama eksik tiple de çalışır.
  static const List<HealthDataType> types = [
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.SKIN_TEMPERATURE,
    HealthDataType.WATER,
  ];

  /// Su, uygulamanın YAZDIĞI tek tip: ana ekran widget'ı için.
  /// Geri kalan her şey salt okunur.
  static const List<HealthDataType> writeTypes = [HealthDataType.WATER];

  /// Yalnızca ana ekran özet widget'ının okuduğu tipler. Uygulama bunları
  /// kendi ekranlarında kullanmıyor, o yüzden 90 günlük okumaya dahil
  /// edilmiyorlar (gereksiz yere yavaşlatırdı); ama izinleri uygulama
  /// üzerinden isteniyor, çünkü widget ayrı bir izin akışı çalıştıramaz.
  static const List<HealthDataType> widgetTypes = [
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// İsteğe bağlı tipler: istenir ama verilmezse uygulama yine açılır.
  /// Antrenmanlar yalnızca Yük sekmesindeki listeyi ve antrenman yükünü
  /// besliyor; skorların hiçbiri onlara bağlı değil.
  static const List<HealthDataType> optionalTypes = [
    HealthDataType.WORKOUT,
    // Döngü: regl kayıtları (Flo, Clue, Samsung Health yazıyor). Hazırlığı
    // döngünün evresine göre düzeltmek için.
    HealthDataType.MENSTRUATION_FLOW,
    // Beslenme: başka uygulamaların yazdığı öğünler (MyFitnessPal, FatSecret...).
    // Kerteriz yemek kaydı tutmuyor, yalnızca okuyor.
    HealthDataType.NUTRITION,
  ];

  /// Her veri tipini hangi uygulamaların yazdığı (tip adı -> kaynak adları).
  /// Veri sekmesi gösteriyor; Samsung ve Garmin gibi HRV paylaşmayan
  /// kaynaklar böyle tanınıyor.
  Map<String, Set<String>> kaynaklar = {};

  /// Bilinen paket adlarının okunur karşılığı. Health Connect kaynak adı
  /// olarak çoğu zaman paket adını veriyor.
  static const Map<String, String> bilinenKaynaklar = {
    'com.sec.android.app.shealth': 'Samsung Health',
    'com.garmin.android.apps.connectmobile': 'Garmin Connect',
    'com.fitbit.FitbitMobile': 'Fitbit',
    'com.google.android.apps.fitness': 'Google Fit',
    'com.google.android.apps.healthdata': 'Health Connect',
    'com.ouraring.oura': 'Oura',
    'com.whoop.android': 'WHOOP',
    'com.xiaomi.wearable': 'Mi Fitness',
    'com.huawei.health': 'Huawei Health',
    'com.withings.wiscale2': 'Withings',
    'com.polar.polarflow': 'Polar Flow',
    'com.ultrahuman.android': 'Ultrahuman',
    'com.myfitnesspal.android': 'MyFitnessPal',
    'com.fatsecret.android': 'FatSecret',
    'org.iggymedia.periodtracker': 'Flo',
    'com.clue.android': 'Clue',
  };

  static String kaynakAdi(HealthDataPoint p) {
    final id = p.sourceId;
    return bilinenKaynaklar[id] ??
        bilinenKaynaklar[p.sourceName] ??
        (p.sourceName.isNotEmpty ? p.sourceName : id);
  }

  void _kaynakEkle(HealthDataPoint p) =>
      kaynaklar.putIfAbsent(p.type.name, () => <String>{}).add(kaynakAdi(p));

  /// İzin ekranında istenen tiplerin tamamı.
  static const List<HealthDataType> permissionTypes = [
    ...types,
    ...widgetTypes,
    ...optionalTypes,
  ];

  Future<void> configure() => _health.configure();

  Future<HealthConnectSdkStatus?> sdkStatus() => _health.getHealthConnectSdkStatus();

  Future<void> installHealthConnect() => _health.installHealthConnect();

  /// KAPI YALNIZCA [types] iledir. Widget'a özel tipler (mesafe, kalori)
  /// burada sorulmaz: onlardan biri verilmediğinde uygulamanın açılmaması
  /// kabul edilemez. Health Connect izin ekranını sınırlı sayıda gösterir;
  /// widget izni yüzünden kapıya takılan kullanıcı uygulamayı bir daha
  /// açamıyordu.
  Future<bool> hasPermissions() async =>
      (await _health.hasPermissions(types, permissions: _access(types))) ?? false;

  /// İstek TEK ekranda hepsini sorar (widget'a özel tipler dahil), ama
  /// sonucu yalnızca [types] üzerinden değerlendirilir.
  Future<bool> requestPermissions() async {
    try {
      await _health.requestAuthorization(permissionTypes,
          permissions: _access(permissionTypes));
    } catch (_) {
      // Tiplerden biri bu cihazda desteklenmiyorsa istek tümden patlayabilir;
      // o durumda yalnızca çekirdek tiplerle tekrar dene.
      try {
        await _health.requestAuthorization(types, permissions: _access(types));
      } catch (_) {}
    }
    return hasPermissions();
  }

  /// İsteğe bağlı izinlerden daha önce hiç sorulmamış olanları bir kez sorar.
  ///
  /// Gerekçe: izin isteği yalnızca zorunlu izinler eksikken çalışıyordu.
  /// Sonradan eklenen bir izin (0.14.0'da antrenmanlar) mevcut kullanıcılara
  /// hiç sorulmuyor, özellik sessizce boş kalıyordu. Reddedilen izin bir daha
  /// sorulmuyor: her açılışta izin ekranı açmak kaba olur.
  Future<void> yeniIzinleriSor() async {
    final sorulmamis = [
      for (final t in optionalTypes)
        if (!Ayarlar.sorulanIzinler.contains(t.name)) t
    ];
    if (sorulmamis.isEmpty) return;
    try {
      final verildi = await _health.hasPermissions(sorulmamis,
              permissions: _access(sorulmamis)) ??
          false;
      if (!verildi) {
        await _health.requestAuthorization(sorulmamis,
            permissions: _access(sorulmamis));
      }
    } catch (_) {
      // Desteklenmiyorsa ya da reddedildiyse uygulama yine çalışır.
    }
    await Ayarlar.izinSoruldu(sorulmamis.map((t) => t.name));
  }

  /// Her tip için erişim seviyesi: su READ_WRITE, diğerleri READ.
  List<HealthDataAccess> _access(List<HealthDataType> list) => [
        for (final t in list)
          writeTypes.contains(t)
              ? HealthDataAccess.READ_WRITE
              : HealthDataAccess.READ
      ];

  // ------------------------------------------------------------------
  // Okuma
  // ------------------------------------------------------------------
  Future<List<DayRecord>> load({int? days}) async {
    final span = days ?? Config.historyDays;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = DateTime(now.year, now.month, now.day - span);

    const wanted = types;
    timedOut.clear();
    // final DEĞİL: aşağıda removeDuplicates sonucuyla yeniden atanıyor.
    List<HealthDataPoint> points = [];

    // TİPLERİ TEK TEK OKUYORUZ. Toplu okuma daha hızlı olurdu ama bir tip
    // eklentiyi çökertirse süreç ölüyor ve hangi tipin yaptığı anlaşılmıyor.
    // Tek tek okuyunca her tipin adı önce ize yazılıyor: uygulama ölse bile
    // bir sonraki açılışta son satır suçluyu gösteriyor.
    for (final t in wanted) {
      // Nabız burada okunmuyor: 90 günlük ham nabız yüz binlerce kayıt eder
      // ve tek seferde belleğe sığmaz, süreç öldürülür. Aşağıda parça parça
      // okunup anında dakikalık kovalara indirgeniyor.
      if (t == HealthDataType.HEART_RATE) continue;
      if (Config.atlananTipler.contains(t.name)) {
        await Tani.iz('tip atlandi: ${t.name}');
        continue;
      }
      await Tani.iz('tip okunuyor: ${t.name}');
      try {
        points.addAll(await _health
            .getHealthDataFromTypes(
              types: [t],
              startTime: start,
              endTime: end,
            )
            .timeout(const Duration(seconds: 15)));
        await Tani.iz('tip tamam: ${t.name}');
      } on TimeoutException {
        timedOut.add(t);
        await Tani.iz('tip ZAMAN ASIMI: ${t.name}');
      } catch (e) {
        await Tani.iz('tip HATA: ${t.name} -> $e');
      }
    }
    await Tani.iz('tipler bitti, kayit: ${points.length}');
    points = _health.removeDuplicates(points);

    // --- kapsama özeti: neyin geldiğini, neyin gelmediğini kaydet ---
    requestedDays = span;
    rawCounts = {};
    kaynaklar = {};
    firstPoint = null;
    lastPoint = null;
    kapsamaZamani = DateTime.now();
    for (final p in points) {
      rawCounts[p.type] = (rawCounts[p.type] ?? 0) + 1;
      _kaynakEkle(p);
      if (firstPoint == null || p.dateFrom.isBefore(firstPoint!)) firstPoint = p.dateFrom;
      if (lastPoint == null || p.dateTo.isAfter(lastPoint!)) lastPoint = p.dateTo;
    }

    // Gün iskeleti: yalnızca istenen pencere kadar gün oluşur.
    // Pencere dışına düşen bir ölçüm (örneğin akşam saatindeki bir kayıt)
    // yeni bir "yarın" kaydı üretmesin diye arama fonksiyonu null döndürür.
    final byDate = <String, DayRecord>{};
    for (var i = 0; i <= span; i++) {
      final d = DateTime(now.year, now.month, now.day - span + i);
      byDate[_key(d)] = DayRecord(d);
    }
    DayRecord? dayFor(DateTime d) => byDate[_key(d)];

    // --- uyku segmentleri ---
    final sleepStages = {
      HealthDataType.SLEEP_DEEP: 'deep',
      HealthDataType.SLEEP_LIGHT: 'light',
      HealthDataType.SLEEP_REM: 'rem',
      HealthDataType.SLEEP_AWAKE: 'awake',
    };
    for (final p in points) {
      final stage = sleepStages[p.type];
      if (stage == null) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      rec.segments.add(SleepSegment(stage, p.dateFrom, p.dateTo));
    }

    // Evre kaydı hiç yoksa SLEEP_SESSION'dan en azından süre çıkar.
    for (final p in points) {
      if (p.type != HealthDataType.SLEEP_SESSION) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      if (rec.segments.isEmpty) {
        rec.bedStart = p.dateFrom;
        rec.wakeEnd = p.dateTo;
        rec.timeInBed = p.dateTo.difference(p.dateFrom).inMinutes;
        rec.asleep = rec.timeInBed;
        rec.light = rec.timeInBed;
      }
    }

    // Gece uykusu ile şekerlemeleri ayır (bkz. uyku_bloklari.dart).
    for (final rec in byDate.values) {
      uykuyuTopla(rec);
    }

    // --- gece pencereli ölçümler ---
    final nightly = <HealthDataType, String>{
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'hrv',
      HealthDataType.RESPIRATORY_RATE: 'resp',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
    };
    final buckets = <String, Map<String, List<double>>>{};
    for (final p in points) {
      final field = nightly[p.type];
      if (field == null && p.type != HealthDataType.SKIN_TEMPERATURE) continue;
      final rec = dayFor(_sleepDay(p.dateTo));
      if (rec == null) continue;
      final v = _num(p);
      if (v == null) continue;
      final key = _key(rec.date);
      buckets.putIfAbsent(key, () => {});
      buckets[key]!.putIfAbsent(field ?? 'temp', () => []).add(v);
    }
    buckets.forEach((key, fields) {
      final rec = byDate[key];
      if (rec == null) return;
      if (fields['hrv'] != null) rec.hrv = _mean(fields['hrv']!);
      if (fields['resp'] != null) rec.respiratory = _mean(fields['resp']!);
      if (fields['temp'] != null) rec.skinTempDelta = _mean(fields['temp']!);
      final ox = fields['spo2'];
      if (ox != null && ox.isNotEmpty) {
        rec.spo2Avg = _mean(ox);
        rec.spo2Min = ox.reduce((a, b) => a < b ? a : b);
      }
    });

    // --- su: gün içinde yazılan bütün kayıtların toplamı ---
    for (final p in points) {
      if (p.type != HealthDataType.WATER) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null) continue;
      final v = _num(p);
      if (v == null) continue;
      // health paketi litre döndürür; ml'ye çeviriyoruz.
      rec.hydrationMl += (v * 1000).round();
    }

    // --- dinlenme nabzı ---
    for (final p in points) {
      if (p.type != HealthDataType.RESTING_HEART_RATE) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null) continue;
      final v = _num(p);
      if (v != null) rec.rhr = v;
    }

    // --- nabız: parça parça oku, anında dakikalık kovalara indirge ---
    //
    // Ham nabız 5 saniyede bir örneklenir: 90 gün ~1.5 milyon kayıt demek.
    // Hepsini birden istemek belleği taşırıyor ve işletim sistemi uygulamayı
    // öldürüyor (açılış ekranında donup kapanmasının sebebi buydu).
    // Çözüm: iki günlük pencerelerle oku, her pencereyi okur okumaz dakika
    // ortalamalarına çevir ve ham kayıtları bırak. Bellekte kalan şey
    // 90 gün x 1440 dakika = ~130 bin sayı, yani bir kaç yüz kilobayt.
    final dakikaSayisi = end.difference(start).inMinutes + 1;
    final hrToplam = Float64List(dakikaSayisi);
    final hrAdet = Int32List(dakikaSayisi);
    var hrKayit = 0;

    int? dakikaIndeksi(DateTime t) {
      final k = t.difference(start).inMinutes;
      return (k < 0 || k >= dakikaSayisi) ? null : k;
    }

    if (!Config.atlananTipler.contains(HealthDataType.HEART_RATE.name)) {
      const pencereGun = 2;
      for (var g = 0; g < span + 1; g += pencereGun) {
        final pStart = start.add(Duration(days: g));
        var pEnd = start.add(Duration(days: g + pencereGun));
        if (pEnd.isAfter(end)) pEnd = end;
        if (!pEnd.isAfter(pStart)) break;

        await Tani.iz('nabiz penceresi: ${_key(pStart)}');
        try {
          final parca = await _health
              .getHealthDataFromTypes(
                types: const [HealthDataType.HEART_RATE],
                startTime: pStart,
                endTime: pEnd,
              )
              .timeout(const Duration(seconds: 20));
          if (parca.isNotEmpty) {
            _kaynakEkle(parca.first);
            _kaynakEkle(parca.last);
          }
          for (final pnt in parca) {
            final v = _num(pnt);
            if (v == null) continue;
            final k = dakikaIndeksi(pnt.dateFrom);
            if (k == null) continue;
            hrToplam[k] += v;
            hrAdet[k] += 1;
            hrKayit++;
            // Kapsama ekranındaki tarih aralığı nabzı da görsün.
            if (firstPoint == null || pnt.dateFrom.isBefore(firstPoint!)) {
              firstPoint = pnt.dateFrom;
            }
            if (lastPoint == null || pnt.dateTo.isAfter(lastPoint!)) {
              lastPoint = pnt.dateTo;
            }
          }
        } on TimeoutException {
          if (!timedOut.contains(HealthDataType.HEART_RATE)) {
            timedOut.add(HealthDataType.HEART_RATE);
          }
          await Tani.iz('nabiz penceresi ZAMAN ASIMI: ${_key(pStart)}');
        } catch (e) {
          await Tani.iz('nabiz penceresi HATA: $e');
        }
      }
      if (hrKayit > 0) rawCounts[HealthDataType.HEART_RATE] = hrKayit;
      await Tani.iz('nabiz bitti, ornek: $hrKayit');
    }

    double? dakikaNabzi(int k) =>
        (k >= 0 && k < dakikaSayisi && hrAdet[k] > 0) ? hrToplam[k] / hrAdet[k] : null;

    for (final rec in byDate.values) {
      // gece eğrisi: yatıştan uyanışa, 10 dakikalık kovalar
      if (rec.bedStart != null && rec.wakeEnd != null) {
        final b0 = dakikaIndeksi(rec.bedStart!);
        final b1 = dakikaIndeksi(rec.wakeEnd!);
        if (b0 != null && b1 != null && b1 > b0) {
          final kovalar = <int, List<double>>{};
          for (var k = b0; k <= b1; k++) {
            final v = dakikaNabzi(k);
            if (v == null) continue;
            kovalar.putIfAbsent(((k - b0) ~/ 10) * 10, () => []).add(v);
          }
          final anahtarlar = kovalar.keys.toList()..sort();
          rec.nightHr = [
            for (final a in anahtarlar) HrSample(a, _mean(kovalar[a]!))
          ];
        }
        // RESTING_HEART_RATE kaydı gelmiyorsa gece nabız serisinden türet.
        // Tek bir dip değeri gürültüye açık; 30 dakikalık en düşük kararlı
        // ortalamayı alıyoruz (üç adet 10 dk'lık kova).
        if (rec.rhr == null && rec.nightHr.length >= 3) {
          double best = double.infinity;
          for (var i = 0; i + 2 < rec.nightHr.length; i++) {
            final avg = (rec.nightHr[i].bpm +
                    rec.nightHr[i + 1].bpm +
                    rec.nightHr[i + 2].bpm) /
                3;
            if (avg < best) best = avg;
          }
          if (best.isFinite) {
            rec.rhr = double.parse(best.toStringAsFixed(1));
            rec.rhrDerived = true;
          }
        } else if (rec.rhr == null && rec.nightHr.isNotEmpty) {
          rec.rhr = rec.nightHr.map((s) => s.bpm).reduce((a, b) => a < b ? a : b);
          rec.rhrDerived = true;
        }
      }

      // bölgeler: veri olan her dakika, o dakikanın ortalamasına göre bir
      // dakika sayılır. Eski hesap örnekler arası boşluğu tahmin ediyordu;
      // dakikalık kova hem daha doğru hem de belleği sabit tutuyor.
      final g0 = dakikaIndeksi(rec.date);
      final g1 = dakikaIndeksi(
          DateTime(rec.date.year, rec.date.month, rec.date.day + 1));
      if (g0 != null && g1 != null) {
        final rest = rec.rhr ?? 60;
        final aralik = Ayarlar.hrMax - rest;
        for (var k = g0; k < g1; k++) {
          final v = dakikaNabzi(k);
          if (v == null) continue;
          final hrr = aralik <= 0 ? 0.0 : (v - rest) / aralik;
          if (hrr >= 0.85) {
            rec.zoneMinutes[4] += 1;
          } else if (hrr >= 0.70) {
            rec.zoneMinutes[3] += 1;
          } else if (hrr >= 0.60) {
            rec.zoneMinutes[2] += 1;
          } else if (hrr >= 0.50) {
            rec.zoneMinutes[1] += 1;
          }
        }
      }
    }

    // --- gün içi dilimler: 15 dakikalık nabız ortalaması ve adım ---
    // Gün içi stres ve enerji bunlardan hesaplanıyor (metrics/gun_ici.dart).
    for (final rec in byDate.values) {
      final g0 = dakikaIndeksi(rec.date);
      if (g0 == null) continue;
      final nabiz = List<double?>.filled(DayRecord.dilimSayisi, null);
      var dolu = false;
      for (var b = 0; b < DayRecord.dilimSayisi; b++) {
        var top = 0.0, n = 0;
        for (var k = 0; k < DayRecord.dilimDk; k++) {
          final v = dakikaNabzi(g0 + b * DayRecord.dilimDk + k);
          if (v == null) continue;
          top += v;
          n++;
        }
        if (n >= 3) {
          nabiz[b] = top / n;
          dolu = true;
        }
      }
      if (dolu) {
        rec.gunNabzi = nabiz;
        rec.gunAdim = List<int>.filled(DayRecord.dilimSayisi, 0);
      }
    }
    for (final p in points) {
      if (p.type != HealthDataType.STEPS) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null || rec.gunAdim.isEmpty) continue;
      final v = _num(p);
      if (v == null) continue;
      final b = p.dateFrom.difference(rec.date).inMinutes ~/ DayRecord.dilimDk;
      if (b >= 0 && b < DayRecord.dilimSayisi) rec.gunAdim[b] += v.round();
    }

    // --- antrenmanlar (isteğe bağlı izin) ---
    // Ayrı okunuyor: izin verilmediyse ya da tip desteklenmiyorsa skorlar
    // etkilenmesin. Yük, o saatlerin dakikalık nabzından günlükle aynı
    // bölge ağırlıklarıyla hesaplanıyor.
    try {
      await Tani.iz('tip okunuyor: WORKOUT');
      final kayitlar = await _health
          .getHealthDataFromTypes(
            types: const [HealthDataType.WORKOUT],
            startTime: start,
            endTime: end,
          )
          .timeout(const Duration(seconds: 15));
      rawCounts[HealthDataType.WORKOUT] = kayitlar.length;
      for (final p in kayitlar.take(50)) {
        _kaynakEkle(p);
      }
      for (final p in kayitlar) {
        final deger = p.value;
        if (deger is! WorkoutHealthValue) continue;
        final rec = dayFor(p.dateFrom);
        if (rec == null) continue;
        final a = Antrenman(deger.workoutActivityType.name, p.dateFrom, p.dateTo);
        a.kcal = deger.totalEnergyBurned;
        a.mesafeM = deger.totalDistance;
        final k0 = dakikaIndeksi(p.dateFrom), k1 = dakikaIndeksi(p.dateTo);
        if (k0 != null && k1 != null && k1 > k0) {
          final rest = rec.rhr ?? 60;
          final aralik = Ayarlar.hrMax - rest;
          var top = 0.0, n = 0;
          double? maks;
          for (var k = k0; k < k1; k++) {
            final v = dakikaNabzi(k);
            if (v == null) continue;
            top += v;
            n++;
            if (maks == null || v > maks) maks = v;
            final hrr = aralik <= 0 ? 0.0 : (v - rest) / aralik;
            final z = hrr >= 0.85
                ? 4
                : hrr >= 0.70
                    ? 3
                    : hrr >= 0.60
                        ? 2
                        : hrr >= 0.50
                            ? 1
                            : 0;
            if (z > 0) a.bolge[z] += 1;
          }
          if (n > 0) a.ortNabiz = top / n;
          a.maksNabiz = maks;
          for (var z = 1; z < 5; z++) {
            a.yukHam += a.bolge[z] * Config.bolgeAgirliklari[z];
          }
        }
        rec.antrenmanlar.add(a);
      }
      for (final rec in byDate.values) {
        rec.antrenmanlar.sort((x, y) => x.bas.compareTo(y.bas));
      }
      await Tani.iz('tip tamam: WORKOUT');
    } catch (e) {
      await Tani.iz('tip HATA: WORKOUT -> $e');
    }

    // --- döngü ve beslenme (isteğe bağlı izinler) ---
    // Antrenmanlar gibi ayrı okunuyor: izin yoksa skorlar etkilenmesin.
    Future<List<HealthDataPoint>> istegeBagli(HealthDataType t) async {
      try {
        await Tani.iz('tip okunuyor: ${t.name}');
        final l = await _health
            .getHealthDataFromTypes(types: [t], startTime: start, endTime: end)
            .timeout(const Duration(seconds: 15));
        rawCounts[t] = l.length;
        for (final p in l.take(50)) {
          _kaynakEkle(p);
        }
        await Tani.iz('tip tamam: ${t.name}');
        return l;
      } catch (e) {
        await Tani.iz('tip HATA: ${t.name} -> $e');
        return const [];
      }
    }

    for (final p in await istegeBagli(HealthDataType.MENSTRUATION_FLOW)) {
      final v = p.value;
      if (v is! MenstruationFlowHealthValue) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null) continue;
      if (v.flow != null && v.flow != MenstrualFlow.none) rec.regl = true;
      if (v.isStartOfCycle == true) rec.donguBaslangici = true;
    }

    for (final p in await istegeBagli(HealthDataType.NUTRITION)) {
      final v = p.value;
      if (v is! NutritionHealthValue) continue;
      final rec = dayFor(p.dateFrom);
      if (rec == null) continue;
      if (v.calories != null && v.calories! > 0) {
        rec.kcalAlinan = (rec.kcalAlinan ?? 0) + v.calories!;
        if (rec.sonOgun == null || p.dateFrom.isAfter(rec.sonOgun!)) {
          rec.sonOgun = p.dateFrom;
        }
      }
      if (v.caffeine != null && v.caffeine! > 0) {
        // health paketi kafeini gram veriyor (Health Connect: inGrams).
        final mg = v.caffeine! * 1000;
        rec.kafeinMg = (rec.kafeinMg ?? 0) + mg;
        if (rec.sonKafein == null || p.dateFrom.isAfter(rec.sonKafein!)) {
          rec.sonKafein = p.dateFrom;
        }
      }
    }

    // --- adım ---
    for (final rec in byDate.values) {
      try {
        final s = await _health.getTotalStepsInInterval(rec.date,
            DateTime(rec.date.year, rec.date.month, rec.date.day + 1));
        rec.steps = s ?? 0;
      } catch (_) {
        rec.steps = 0;
      }
    }

    final list = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ------------------------------------------------------------------
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sabah 18:00'dan önce biten uyku, bittiği takvim gününe yazılır.
  static DateTime _sleepDay(DateTime end) {
    final d = end.hour < 18 ? end : end.add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day);
  }

  static double? _num(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  static double _mean(List<double> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length;
}
