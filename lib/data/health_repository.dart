import 'dart:async';
import 'dart:typed_data';

import 'package:health/health.dart';

import '../config.dart';
import 'ayarlar.dart';
import 'day_record.dart';
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

  /// İzin ekranında istenen tiplerin tamamı.
  static const List<HealthDataType> permissionTypes = [...types, ...widgetTypes];

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
    firstPoint = null;
    lastPoint = null;
    kapsamaZamani = DateTime.now();
    for (final p in points) {
      rawCounts[p.type] = (rawCounts[p.type] ?? 0) + 1;
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

    for (final rec in byDate.values) {
      if (rec.segments.isEmpty) continue;
      rec.segments.sort((a, b) => a.start.compareTo(b.start));
      rec.bedStart = rec.segments.first.start;
      rec.wakeEnd = rec.segments.last.end;
      rec.timeInBed = rec.wakeEnd!.difference(rec.bedStart!).inMinutes;
      for (final s in rec.segments) {
        switch (s.stage) {
          case 'deep':
            rec.deep += s.minutes;
            break;
          case 'rem':
            rec.rem += s.minutes;
            break;
          case 'light':
            rec.light += s.minutes;
            break;
          case 'awake':
            rec.awakeMinutes += s.minutes;
            rec.awakenings += 1;
            break;
        }
      }
      rec.asleep = rec.deep + rec.rem + rec.light;
      if (rec.asleep == 0) rec.asleep = rec.timeInBed - rec.awakeMinutes;
      if (rec.timeInBed < rec.asleep) rec.timeInBed = rec.asleep + rec.awakeMinutes;
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
