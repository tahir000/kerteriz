import 'dart:math' as math;

import 'package:intl/intl.dart';

class HrSample {
  final int minute; // gecenin başından itibaren dakika
  final double bpm;
  const HrSample(this.minute, this.bpm);
  Map<String, dynamic> toJson() => {'m': minute, 'v': bpm};
  factory HrSample.fromJson(Map<String, dynamic> j) =>
      HrSample((j['m'] as num).toInt(), (j['v'] as num).toDouble());
}

class SleepSegment {
  final String stage; // deep | light | rem | awake
  final DateTime start;
  final DateTime end;
  const SleepSegment(this.stage, this.start, this.end);
  int get minutes => end.difference(start).inMinutes;
  Map<String, dynamic> toJson() => {
        'stage': stage,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
  factory SleepSegment.fromJson(Map<String, dynamic> j) => SleepSegment(
        j['stage'] as String,
        DateTime.parse(j['start'] as String),
        DateTime.parse(j['end'] as String),
      );
}

/// Health Connect'teki bir egzersiz kaydı ve o saatlerin nabzından
/// hesaplanan yükü.
class Antrenman {
  /// HealthWorkoutActivityType adı: RUNNING, WALKING, STRENGTH_TRAINING...
  final String tur;
  final DateTime bas;
  final DateTime bit;
  double? ortNabiz;
  double? maksNabiz;

  /// Nabız bölgelerinde geçen dakika; 0 kullanılmıyor, 1..4 (günlükle aynı).
  List<double> bolge = [0, 0, 0, 0, 0];

  /// Bölge ağırlıklı dakikalar (TRIMP); günlük yükün ham karşılığı.
  double yukHam = 0;
  int? kcal;
  int? mesafeM;

  Antrenman(this.tur, this.bas, this.bit);

  int get dakika => bit.difference(bas).inMinutes;

  /// Günlük yükle aynı 0-21 logaritmik ölçek.
  double get yuk => (6.9 * math.log(1 + yukHam / 24)).clamp(0, 21).toDouble();

  Map<String, dynamic> toJson() => {
        'tur': tur,
        'bas': bas.toIso8601String(),
        'bit': bit.toIso8601String(),
        'ortNabiz': ortNabiz,
        'maksNabiz': maksNabiz,
        'bolge': bolge,
        'yukHam': yukHam,
        'kcal': kcal,
        'mesafeM': mesafeM,
      };

  factory Antrenman.fromJson(Map<String, dynamic> j) {
    final a = Antrenman(j['tur'] as String, DateTime.parse(j['bas'] as String),
        DateTime.parse(j['bit'] as String));
    a.ortNabiz = (j['ortNabiz'] as num?)?.toDouble();
    a.maksNabiz = (j['maksNabiz'] as num?)?.toDouble();
    final b = j['bolge'];
    if (b is List && b.length == 5) {
      a.bolge = b.map((e) => (e as num).toDouble()).toList();
    }
    a.yukHam = (j['yukHam'] as num?)?.toDouble() ?? 0;
    a.kcal = (j['kcal'] as num?)?.toInt();
    a.mesafeM = (j['mesafeM'] as num?)?.toInt();
    return a;
  }
}

/// Bir "gün" = o sabah biten gece + o günün aktivitesi.
class DayRecord {
  final DateTime date; // uyanılan takvim günü (yerel, gece yarısı)

  // --- ham ---
  DateTime? bedStart;
  DateTime? wakeEnd;
  int timeInBed = 0;
  int asleep = 0;
  int deep = 0;
  int rem = 0;
  int light = 0;
  int awakeMinutes = 0;
  int awakenings = 0;

  /// Gece uykusu dışındaki bloklarda (şekerleme) uyunan dakika. Uyku
  /// skoruna girmez, uyku borcunu azaltır.
  int napMinutes = 0;
  List<SleepSegment> segments = [];
  List<HrSample> nightHr = [];

  double? hrv; // RMSSD, ms
  double? rhr; // atım/dk
  bool rhrDerived = false; // kayıt yoktu, gece nabız serisinden türetildi
  double? respiratory; // soluk/dk
  double? skinTempDelta; // C
  double? spo2Avg;
  double? spo2Min;
  int steps = 0;
  int hydrationMl = 0; // su widget'ı Health Connect'e yazıyor, buradan okunuyor
  List<double> zoneMinutes = [0, 0, 0, 0, 0]; // 0 kullanılmıyor, 1..4

  /// O günün antrenmanları (başlangıç saatine göre sıralı).
  List<Antrenman> antrenmanlar = [];

  /// Gün içi 15 dakikalık dilimler (96 adet, gece yarısından): dilimin
  /// ortalama nabzı ve adımı. Gün içi stres ve enerji bunlardan hesaplanıyor.
  /// Boş liste: veri yok (önbellekte eski günler için saklanmıyor).
  // --- döngü (Health Connect regl kayıtları) ---
  /// O gün regl kaydı var mı (akış "yok" dışında herhangi bir değer).
  bool regl = false;

  /// Health Connect'ten gelen regl bilgisi. [regl] buna uygulama içinden
  /// işaretlenen günlerin eklenmesiyle oluşuyor (ReglKayitlari.uygula).
  bool reglHc = false;

  /// Kayıt döngünün başlangıcı olarak işaretlenmiş mi.
  bool donguBaslangici = false;

  // --- beslenme (Health Connect; başka uygulamalar yazıyor) ---
  double? kcalAlinan;

  /// O günün son öğün kaydının saati (öğünü kaydeden uygulamanın verdiği).
  DateTime? sonOgun;
  double? kafeinMg;
  DateTime? sonKafein;

  // --- türetilmiş döngü bilgisi (metrics/dongu.dart dolduruyor) ---
  int? donguGunu;

  /// 'regl', 'folikuler', 'luteal' ya da null (döngü bilinmiyor).
  String? donguEvresi;

  /// Hazırlık hesabında döngü düzeltmesi uygulandı mı.
  bool donguDuzeltildi = false;

  /// HRV gelmediği için gece kardiyak toparlanması hazırlığa katıldı mı.
  bool kardiyakYedek = false;

  List<double?> gunNabzi = [];
  List<int> gunAdim = [];
  static const int dilimDk = 15;
  static const int dilimSayisi = 96;

  // --- türetilmiş (engine dolduruyor) ---
  double hrvZ = 0, rhrZ = 0, respZ = 0, tempZ = 0;
  double? hrvBaseline, hrvBaselineSd, rhrBaseline;

  /// Taban çizgiyi kuran önceki gece sayısı (pencere içinde, en çok 14).
  /// [Config.minBaselineNights] altındaysa o girdi hazırlığa katılmaz.
  int hrvBaselineN = 0, rhrBaselineN = 0;

  /// Kalp girdilerinden en iyi kurulmuş olanın gece sayısı. Kalibrasyon
  /// göstergesi bunu kullanıyor.
  int get baselineNights =>
      hrvBaselineN > rhrBaselineN ? hrvBaselineN : rhrBaselineN;
  double strainRaw = 0, strain = 0;
  int need = 0;
  int sleepScore = 0;
  Map<String, double> sleepParts = {};
  int readiness = 0;
  int debtMinutes = 0;
  double acute = 0, chronic = 0, acwr = 1;

  /// Akut/kronik oranı ancak 28 günlük kronik pencere gerçekten dolduğunda
  /// anlamlı. Soğuk başlangıçta pencerenin çoğu boş gün olur ve oran
  /// olduğundan büyük çıkar; o durumda oranı göstermiyoruz.
  bool acwrReady = false;
  int cardiac = 0;
  double? nadirBpm;
  int? nadirMinute;

  DayRecord(this.date);

  bool get hasSleep => asleep > 0;

  /// 20:00'dan itibaren dakika cinsinden yatış anı (raster ve zamanlama için).
  double? get bedOffset {
    if (bedStart == null) return null;
    final anchor = DateTime(date.year, date.month, date.day - 1, 20);
    return bedStart!.difference(anchor).inMinutes.toDouble();
  }

  double? get sleepMidpoint {
    final b = bedOffset;
    if (b == null) return null;
    return b + timeInBed / 2;
  }

  /// Etiketlerin dili. Uygulama açılırken cihaz diline göre ayarlanır.
  static String locale = 'en';

  String get label => DateFormat('d MMM', locale).format(date);

  /// [geceNabzi] false ise dakikalık gece nabız serisi yazılmaz.
  ///
  /// Önbellek bunu kullanıyor: seri gün başına ~700 örnek, 90 gün için
  /// megabaytlara çıkıyor ve yalnızca kardiyak toparlanma ile türetilmiş
  /// dinlenme nabzı için okunuyor. İkisi de zaten hesaplanıp kaydın içine
  /// yazıldığı için eski günlerde seriyi saklamanın anlamı yok.
  Map<String, dynamic> toJson({bool geceNabzi = true}) => {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'bedStart': bedStart?.toIso8601String(),
        'wakeEnd': wakeEnd?.toIso8601String(),
        'timeInBed': timeInBed,
        'asleep': asleep,
        'deep': deep,
        'rem': rem,
        'light': light,
        'awakeMinutes': awakeMinutes,
        'awakenings': awakenings,
        'napMinutes': napMinutes,
        'hrv': hrv,
        'rhr': rhr,
        'rhrDerived': rhrDerived,
        'respiratory': respiratory,
        'skinTempDelta': skinTempDelta,
        'spo2Avg': spo2Avg,
        'spo2Min': spo2Min,
        'steps': steps,
        'hydrationMl': hydrationMl,
        'zoneMinutes': zoneMinutes,
        'segments': segments.map((s) => s.toJson()).toList(),
        'nightHr':
            geceNabzi ? nightHr.map((s) => s.toJson()).toList() : const [],
        'antrenmanlar': antrenmanlar.map((a) => a.toJson()).toList(),
        // Yalnızca Health Connect'ten gelen; yerel işaretler ayrı dosyada.
        'regl': reglHc,
        'donguBaslangici': donguBaslangici,
        'kcalAlinan': kcalAlinan,
        'sonOgun': sonOgun?.toIso8601String(),
        'kafeinMg': kafeinMg,
        'sonKafein': sonKafein?.toIso8601String(),
        // Gün içi dilimler de gece nabzı gibi yalnızca son günlerde tutuluyor.
        'gunNabzi': geceNabzi ? gunNabzi : const [],
        'gunAdim': geceNabzi ? gunAdim : const [],
        'derived': {
          'hrvZ': hrvZ,
          'rhrZ': rhrZ,
          'respZ': respZ,
          'tempZ': tempZ,
          'strain': strain,
          'need': need,
          'sleepScore': sleepScore,
          'sleepParts': sleepParts,
          'readiness': readiness,
          'debtMinutes': debtMinutes,
          'acute': acute,
          'chronic': chronic,
          'acwr': acwr,
          'acwrReady': acwrReady,
          'cardiac': cardiac,
          'nadirBpm': nadirBpm,
          'nadirMinute': nadirMinute,
        },
      };

  /// [toJson] çıktısından kaydı geri kurar. Önbellek için; türetilmiş
  /// alanlar da geri yükleniyor çünkü motor onları yeniden hesaplarken
  /// elindeki ham veriye bakıyor ve gece nabzı önbellekte tutulmuyor.
  factory DayRecord.fromJson(Map<String, dynamic> j) {
    double? say(String k) => (j[k] as num?)?.toDouble();
    final d = DayRecord(DateTime.parse(j['date'] as String));
    final bs = j['bedStart'], we = j['wakeEnd'];
    d.bedStart = bs is String ? DateTime.parse(bs) : null;
    d.wakeEnd = we is String ? DateTime.parse(we) : null;
    d.timeInBed = (j['timeInBed'] as num?)?.toInt() ?? 0;
    d.asleep = (j['asleep'] as num?)?.toInt() ?? 0;
    d.deep = (j['deep'] as num?)?.toInt() ?? 0;
    d.rem = (j['rem'] as num?)?.toInt() ?? 0;
    d.light = (j['light'] as num?)?.toInt() ?? 0;
    d.awakeMinutes = (j['awakeMinutes'] as num?)?.toInt() ?? 0;
    d.awakenings = (j['awakenings'] as num?)?.toInt() ?? 0;
    d.napMinutes = (j['napMinutes'] as num?)?.toInt() ?? 0;
    d.hrv = say('hrv');
    d.rhr = say('rhr');
    d.rhrDerived = j['rhrDerived'] == true;
    d.respiratory = say('respiratory');
    d.skinTempDelta = say('skinTempDelta');
    d.spo2Avg = say('spo2Avg');
    d.spo2Min = say('spo2Min');
    d.steps = (j['steps'] as num?)?.toInt() ?? 0;
    d.hydrationMl = (j['hydrationMl'] as num?)?.toInt() ?? 0;

    final zm = j['zoneMinutes'];
    if (zm is List && zm.length == 5) {
      d.zoneMinutes = zm.map((e) => (e as num).toDouble()).toList();
    }
    final sg = j['segments'];
    if (sg is List) {
      d.segments = sg
          .map((e) => SleepSegment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final nh = j['nightHr'];
    if (nh is List) {
      d.nightHr =
          nh.map((e) => HrSample.fromJson(e as Map<String, dynamic>)).toList();
    }

    d.reglHc = d.regl = j['regl'] == true;
    d.donguBaslangici = j['donguBaslangici'] == true;
    d.kcalAlinan = say('kcalAlinan');
    d.kafeinMg = say('kafeinMg');
    final so = j['sonOgun'], sk = j['sonKafein'];
    d.sonOgun = so is String ? DateTime.parse(so) : null;
    d.sonKafein = sk is String ? DateTime.parse(sk) : null;
    final an = j['antrenmanlar'];
    if (an is List) {
      d.antrenmanlar =
          an.map((e) => Antrenman.fromJson(e as Map<String, dynamic>)).toList();
    }
    final gn = j['gunNabzi'];
    if (gn is List && gn.length == dilimSayisi) {
      d.gunNabzi = gn.map((e) => (e as num?)?.toDouble()).toList();
    }
    final ga = j['gunAdim'];
    if (ga is List && ga.length == dilimSayisi) {
      d.gunAdim = ga.map((e) => (e as num).toInt()).toList();
    }

    final t = j['derived'];
    if (t is Map<String, dynamic>) {
      double tur(String k) => (t[k] as num?)?.toDouble() ?? 0;
      d.hrvZ = tur('hrvZ');
      d.rhrZ = tur('rhrZ');
      d.respZ = tur('respZ');
      d.tempZ = tur('tempZ');
      d.strain = tur('strain');
      d.need = (t['need'] as num?)?.toInt() ?? 0;
      d.sleepScore = (t['sleepScore'] as num?)?.toInt() ?? 0;
      final sp = t['sleepParts'];
      if (sp is Map) {
        d.sleepParts = sp.map((k, v) => MapEntry('$k', (v as num).toDouble()));
      }
      d.readiness = (t['readiness'] as num?)?.toInt() ?? 0;
      d.debtMinutes = (t['debtMinutes'] as num?)?.toInt() ?? 0;
      d.acute = tur('acute');
      d.chronic = tur('chronic');
      d.acwr = (t['acwr'] as num?)?.toDouble() ?? 1;
      d.acwrReady = t['acwrReady'] == true;
      d.cardiac = (t['cardiac'] as num?)?.toInt() ?? 0;
      d.nadirBpm = (t['nadirBpm'] as num?)?.toDouble();
      d.nadirMinute = (t['nadirMinute'] as num?)?.toInt();
    }
    return d;
  }
}
