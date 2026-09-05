import 'package:flutter/widgets.dart';

/// Hafif coklu dil katmani.
///
/// Kod uretimi ya da ARB dosyalari yok: tek bir sinif, iki harita.
/// Yeni dil eklemek icin `_en` gibi bir harita daha yazip `_all`'a koymak yeterli.
/// Bilinmeyen bir dil gelirse Ingilizceye duser.
class S {
  final Map<String, String> _m;
  final String code;
  const S(this.code, this._m);

  static const _fallback = 'en';
  static const Map<String, Map<String, String>> _all = {'tr': _tr, 'en': _en};

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return S(code, _all[code] ?? _all[_fallback]!);
  }

  static S forCode(String code) => S(code, _all[code] ?? _all[_fallback]!);

  static List<Locale> get supported =>
      _all.keys.map((c) => Locale(c)).toList(growable: false);

  String t(String key) => _m[key] ?? _all[_fallback]![key] ?? key;

  /// Yer tutuculu metin:  t2('sleep.caption', {'a': '7s 30d'})
  String t2(String key, Map<String, String> vars) {
    var s = t(key);
    vars.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  bool get isTr => code == 'tr';

  // ---------------------------------------------------------------
  static const Map<String, String> _tr = {
    'app.name': 'Kerteriz',

    // sekmeler
    'tab.today': 'Bugun',
    'tab.sleep': 'Uyku',
    'tab.load': 'Yuk',
    'tab.heart': 'Kalp',
    'tab.data': 'Veri',

    // genel
    'unit.of100': '/100',
    'unit.of21': '/21',
    'unit.ms': ' ms',
    'unit.bpm': ' atim',
    'unit.min': ' dk',
    'unit.night': ' gece',
    'unit.day': ' gun',
    'unit.record': ' kayit',
    'unit.perMin': '/dk',
    'unit.z': ' z',
    'common.retry': 'Yeniden oku',
    'common.yes': 'evet',
    'common.no': 'hayir',
    'common.none': 'yok',
    'common.hourShort': 's',
    'common.minShort': 'd',

    // seviyeler
    'lvl.good': 'iyi',
    'lvl.watch': 'izlenmeli',
    'lvl.low': 'dusuk',
    'lvl.ready': 'hazir',
    'lvl.medium': 'orta',
    'lvl.normal': 'normal',
    'lvl.below': 'altinda',
    'lvl.wellBelow': 'belirgin altinda',
    'lvl.inBand': 'bant ici',
    'lvl.borderline': 'sinirda',
    'lvl.risky': 'riskli',
    'lvl.accumulating': 'birikiyor',
    'lvl.high': 'yuksek',
    'lvl.steady': 'sabit',
    'lvl.drifting': 'kayiyor',
    'lvl.deviation': 'sapma',
    'lvl.veryRegular': 'cok duzenli',
    'lvl.variable': 'degisken',
    'lvl.irregular': 'duzensiz',
    'lvl.flowing': 'akiyor',
    'lvl.derived': 'turetildi',
    'lvl.present': 'var',
    'lvl.empty': 'bos',
    'lvl.on': 'acik',
    'lvl.off': 'kapali',
    'lvl.working': 'calisiyor',
    'lvl.noData': 'veri yok',
    'lvl.full': 'tam',
    'lvl.partial': 'kismi',
    'lvl.enough': 'yeterli',
    'lvl.building': 'biriktiriyor',
    'lvl.tooFew': 'cok az',

    // durum ekranlari
    'state.reading': 'Health Connect okunuyor…',
    'state.noRecords': 'Health Connect hic kayit dondurmedi.',
    'state.noSdk': 'Bu cihazda Health Connect yok.',
    'state.updateSdk': 'Health Connect guncellenmeli. Guncelledikten sonra tekrar dene.',
    'state.noPermission': 'Health Connect izinleri verilmedi.',
    'state.readError': 'Veri okunamadi',
    'state.noSleep': 'Dun geceye ait uyku kaydi bulunamadi.',

    // bugun
    'today.title': 'Bugun',
    'today.today': 'bugun',
    'today.readiness': 'Hazirlik',
    'today.inputs': 'Hazirligi olusturan girdiler',
    'today.hrv': 'HRV',
    'today.hrvSub': 'Gece ortalama RMSSD, 14 gunluk logaritmik taban cizgine gore',
    'today.rhr': 'Dinlenme nabzi',
    'today.rhrSub': 'Dusuk olmasi iyi; isaret ters cevrilmis',
    'today.respTemp': 'Solunum + cilt sicakligi',
    'today.respTempSub': 'Hastalik icin en erken iki sinyal',
    'today.sleepScore': 'Uyku skoru',
    'today.weight25': 'Agirligi %25',
    'today.forToday': 'Bugun icin',
    'today.suggestedLoad': 'Onerilen yuk',
    'today.suggestedLoadSub': 'Hazirliga gore hedef bant',
    'today.debt': 'Uyku borcu',
    'today.debtSub': 'Son 14 gun, sonumlenerek',
    'today.loadRatio': 'Yuk orani',
    'today.loadRatioSub': 'Akut / kronik',
    'today.last30': 'Son 30 gun hazirlik',
    'today.caption':
        'Dun gece {sleep} uyudun (ihtiyac {need}). HRV {hrv} ms, dinlenme nabzi {rhr} atim.',
    'today.captionNoSleep':
        'Dun geceye ait uyku kaydi bulunamadi; hazirlik yalnizca kalp verisinden hesaplandi.',
    'today.chartNote':
        'Her sutun bir gun; renk o gunun seviyesi. Renk tek basina birakilmadi — '
            'her yerde yaninda seviye etiketi ve sayinin kendisi var.',
    'today.illness':
        'Vucudun bir seyle ugrasiyor. Solunum hizi, cilt sicakligi ve dinlenme nabzi '
            'ayni anda taban cizginin uzerinde. Bu ucluye birlikte bakmak, tek basina '
            'nabza bakmaktan daha erken uyarir.',
    'today.overload':
        'Yuklenme birikiyor. Akut/kronik yuk orani {acwr} ve HRV uc gundur taban '
            'cizginin altinda.',

    // uyku
    'sleep.title': 'Uyku',
    'sleep.lastNight': 'Dun gece',
    'sleep.score': 'Uyku skoru',
    'sleep.caption':
        '{sleep} uyku, {bed} yatakta. Onarici evreler (derin + REM) gecenin %{pct}\'i '
            '— hedef bant %38–46.',
    'sleep.throughNight': 'Gece boyunca',
    'sleep.stages': 'Evre dagilimi',
    'sleep.components': 'Bilesenler',
    'sleep.deeper': 'Daha derin',
    'sleep.last14': 'Son 14 gecenin suresi',
    'sleep.windowMap': 'Uyku penceresi haritasi',
    'sleep.need': 'ihtiyac',
    'sleep.deep': 'Derin',
    'sleep.light': 'Hafif',
    'sleep.rem': 'REM',
    'sleep.awake': 'Uyanik',
    'sleep.duration': 'Sure',
    'sleep.efficiency': 'Verim',
    'sleep.restoration': 'Onarim',
    'sleep.continuity': 'Kesintisizlik',
    'sleep.timing': 'Zamanlama',
    'sleep.weight': 'Agirlik %{w}',
    'sleep.debt': 'Uyku borcu',
    'sleep.debtSub': 'Son 14 gun, eski gunler sonumlenerek',
    'sleep.sri': 'Sirkadiyen duzenlilik',
    'sleep.sriSub': 'Uyku penceren gunden gune ne kadar sabit',
    'sleep.cardiac': 'Gece kardiyak toparlanma',
    'sleep.cardiacSub': 'Nabzin ne kadar ve ne kadar erken dustugu',
    'sleep.eff': 'Uyku verimi',
    'sleep.effSub': 'Yatakta gecen surenin uykuya donen kismi',
    'sleep.rasterNote':
        'Her satir bir gece, bant uykuda gectigin sure; rengi o gecenin uyku skoru. '
            'Bantlarin ust uste binmesi — saatlerin degil — sirkadiyen duzenliligin olcusudur.',

    // yuk
    'load.title': 'Yuk',
    'load.daily': 'Gunluk yuk',
    'load.caption':
        'Bolge agirlikli nabiz dakikalarindan hesaplanir; olcek logaritmiktir. '
            'Bugun {min} dakikan bolge 1 ustunde gecti.',
    'load.balance': 'Yuk dengesi',
    'load.acute': 'Akut yuk',
    'load.acuteSub': 'Son 7 gun ortalamasi',
    'load.chronic': 'Kronik yuk',
    'load.chronicSub': 'Son 28 gun ortalamasi',
    'load.ratio': 'Akut / kronik orani',
    'load.ratioSub': '0.80–1.30 arasi surdurulebilir bant',
    'load.last28': 'Son 28 gun',
    'load.avg28': '28 gun ort.',
    'load.zones': 'Bugunun nabiz bolgeleri',
    'load.zone': 'Bolge {n}',
    'load.steps': 'Adim',
    'load.zoneNote':
        'Sutunun rengi o gunun akut/kronik oranini gosterir: yesil, vucudunun alistigi '
            'tempo; turuncu sinir; kirmizi, yuku alistigindan hizli artirdigin gunler.',

    // kalp
    'heart.title': 'Kalp ve solunum',
    'heart.last45': 'Son 45 gun',
    'heart.hrvTag': 'Gece HRV (RMSSD)',
    'heart.hrvCaption':
        'Gri serit, 14 gunluk taban cizginin ±1 standart sapmasi. Onemli olan tek '
            'gecenin degeri degil, serideki konumun.',
    'heart.hrvMissing':
        'Health Connect bu cihazda HRV yazmiyor gorunuyor. Hazirlik skoru, kalan '
            'girdilerin agirliklari yeniden dagitilarak hesaplandi.',
    'heart.measured': 'Olculen degerler',
    'heart.hrv': 'Kalp hizi degiskenligi',
    'heart.hrvSub': 'Taban cizgiye gore {z} z',
    'heart.rhr': 'Dinlenme nabzi',
    'heart.rhrSub': 'Uyku sirasindaki en dusuk kararli deger',
    'heart.rhrDerivedSub': 'Gece nabiz serisinden turetildi',
    'heart.spo2': 'Gece SpO2',
    'heart.spo2Sub': 'En dusuk {min}%',
    'heart.resp': 'Solunum hizi',
    'heart.respSub': 'Hastalikta genelde ilk kipirdayan sinyal',
    'heart.temp': 'Cilt sicakligi sapmasi',
    'heart.tempSub': 'Kendi gece ortalamandan fark',
    'heart.rhrHistory': 'Dinlenme nabzi · tum gecmis',

    // veri
    'data.title': 'Veri kapsami',
    'data.source': 'Health Connect',
    'data.nightsWithSleep': 'Uyku kaydi olan gece',
    'data.enoughCaption': 'Taban cizgiler icin yeterli gecmis var; skorlar anlamli.',
    'data.thinCaption':
        'Taban cizgiler onceki 14 gecenin ortalamasindan kuruluyor. O sayiya '
            'ulasana kadar z-skorlari sifira yakin kalir. Bekleyerek duzelir.',
    'data.summary': 'Ozet',
    'data.requested': 'Istenen aralik',
    'data.requestedSub': 'Uygulamanin geriye dogru sordugu gun sayisi',
    'data.range': 'Gelen kaydin tarih araligi',
    'data.noRange': 'Hic kayit gelmedi',
    'data.hrvNights': 'HRV olan gece',
    'data.hrvNightsSub': 'Hazirlik skorunda agirligi %40',
    'data.rhrDays': 'Dinlenme nabzi olan gun',
    'data.rhrDaysSub': 'Agirligi %25',
    'data.rhrDerivedSub': '{n} gunu gece nabiz serisinden turetildi',
    'data.capabilities': 'Hesaplanabilen metrikler',
    'data.capReadiness': 'Hazirlik skoru',
    'data.capReadinessSub': 'Gelen girdilerin agirliklari yeniden dagitilir',
    'data.capSleep': 'Uyku skoru ve borcu',
    'data.capSleepSub': 'Yalnizca uyku evrelerine bagli',
    'data.capLoad': 'Gunluk yuk ve ACWR',
    'data.capLoadSub': 'Nabiz bolgeleri ve adimdan',
    'data.capIllness': 'Hastalik erken uyarisi',
    'data.capIllnessSub': 'Solunum hizi ve cilt sicakligi gerekiyor',
    'data.capSpo2': 'Gece SpO2 takibi',
    'data.capSpo2Sub': 'Kandaki oksijen kaydi gerekiyor',
    'data.byType': 'Tip tip gelen kayit',
    'data.usedInScores': 'Skorlarda dogrudan kullaniliyor',
    'data.derivedNote':
        'Dinlenme nabzi kaydi gelmiyor ama gece nabiz serisi geliyor, bu yuzden deger '
            'seriden turetiliyor: gecenin en dusuk 30 dakikalik kararli ortalamasi. '
            'Cihazin yazdigi degerden biraz farkli cikabilir, ama kendi icinde tutarli '
            'oldugu icin taban cizgi ve z-skoru dogru calisir.',
    'data.missingNote':
        'Sifir gorunen tipler icin sirasiyla sunlara bak: Google Health uygulamasinda '
            'cihaz bagli mi; Health Connect ekraninda Google Health bu tipi yazmaya '
            'yetkili mi; bu uygulama o tipi okumaya yetkili mi.',
    'data.privacyNote':
        'Butun okuma cihazda yapiliyor. Hicbir veri disari cikmiyor; bu ekran da '
            'yalnizca telefonun kendi Health Connect deposundan ne geldigini gosteriyor.',
    'data.export': 'Veriyi disa aktar',
    'data.exportFailed': 'Disa aktarilamadi',
    'data.exportSubject': 'Kerteriz veri disa aktarimi',

    // veri tipleri
    'type.deepSleep': 'Derin uyku',
    'type.lightSleep': 'Hafif uyku',
    'type.remSleep': 'REM uykusu',
    'type.awake': 'Uyanik donemler',
    'type.sleepSession': 'Uyku oturumu',
    'type.heartRate': 'Nabiz',
    'type.restingHr': 'Dinlenme nabzi',
    'type.hrv': 'HRV (RMSSD)',
    'type.respiratory': 'Solunum hizi',
    'type.spo2': 'Kandaki oksijen',
    'type.skinTemp': 'Cilt sicakligi',
    'type.steps': 'Adim',

    // yasal
    'legal.disclaimer':
        'Bu uygulama teshis koymaz ve tibbi tavsiye vermez. Kendi verini kendi taban '
            'cizgine gore gosterir. Saglikla ilgili kararlar icin bir hekime danis.',
  };

  // ---------------------------------------------------------------
  static const Map<String, String> _en = {
    'app.name': 'Kerteriz',

    'tab.today': 'Today',
    'tab.sleep': 'Sleep',
    'tab.load': 'Load',
    'tab.heart': 'Heart',
    'tab.data': 'Data',

    'unit.of100': '/100',
    'unit.of21': '/21',
    'unit.ms': ' ms',
    'unit.bpm': ' bpm',
    'unit.min': ' min',
    'unit.night': ' nights',
    'unit.day': ' days',
    'unit.record': ' records',
    'unit.perMin': '/min',
    'unit.z': ' z',
    'common.retry': 'Read again',
    'common.yes': 'yes',
    'common.no': 'no',
    'common.none': 'none',
    'common.hourShort': 'h',
    'common.minShort': 'm',

    'lvl.good': 'good',
    'lvl.watch': 'watch',
    'lvl.low': 'low',
    'lvl.ready': 'ready',
    'lvl.medium': 'moderate',
    'lvl.normal': 'normal',
    'lvl.below': 'below',
    'lvl.wellBelow': 'well below',
    'lvl.inBand': 'in range',
    'lvl.borderline': 'borderline',
    'lvl.risky': 'risky',
    'lvl.accumulating': 'building',
    'lvl.high': 'high',
    'lvl.steady': 'steady',
    'lvl.drifting': 'drifting',
    'lvl.deviation': 'deviating',
    'lvl.veryRegular': 'very regular',
    'lvl.variable': 'variable',
    'lvl.irregular': 'irregular',
    'lvl.flowing': 'flowing',
    'lvl.derived': 'derived',
    'lvl.present': 'present',
    'lvl.empty': 'empty',
    'lvl.on': 'on',
    'lvl.off': 'off',
    'lvl.working': 'working',
    'lvl.noData': 'no data',
    'lvl.full': 'complete',
    'lvl.partial': 'partial',
    'lvl.enough': 'sufficient',
    'lvl.building': 'building up',
    'lvl.tooFew': 'too few',

    'state.reading': 'Reading Health Connect…',
    'state.noRecords': 'Health Connect returned no records.',
    'state.noSdk': 'Health Connect is not available on this device.',
    'state.updateSdk': 'Health Connect needs an update. Try again once updated.',
    'state.noPermission': 'Health Connect permissions were not granted.',
    'state.readError': 'Could not read data',
    'state.noSleep': 'No sleep record found for last night.',

    'today.title': 'Today',
    'today.today': 'today',
    'today.readiness': 'Readiness',
    'today.inputs': 'What readiness is built from',
    'today.hrv': 'HRV',
    'today.hrvSub': 'Nightly mean RMSSD, against a 14-day logarithmic baseline',
    'today.rhr': 'Resting heart rate',
    'today.rhrSub': 'Lower is better; the sign is inverted',
    'today.respTemp': 'Respiration + skin temperature',
    'today.respTempSub': 'The two earliest signals of illness',
    'today.sleepScore': 'Sleep score',
    'today.weight25': 'Weighted 25%',
    'today.forToday': 'For today',
    'today.suggestedLoad': 'Suggested load',
    'today.suggestedLoadSub': 'Target band based on readiness',
    'today.debt': 'Sleep debt',
    'today.debtSub': 'Last 14 days, decayed',
    'today.loadRatio': 'Load ratio',
    'today.loadRatioSub': 'Acute / chronic',
    'today.last30': 'Readiness · last 30 days',
    'today.caption':
        'You slept {sleep} last night (need {need}). HRV {hrv} ms, resting heart rate {rhr} bpm.',
    'today.captionNoSleep':
        'No sleep record for last night; readiness was computed from heart data alone.',
    'today.chartNote':
        'Each bar is a day; the color is that day\'s level. Color never stands alone — '
            'a level label and the number itself sit next to it everywhere.',
    'today.illness':
        'Your body is dealing with something. Respiration, skin temperature and resting '
            'heart rate are all above baseline at once. Reading the three together warns '
            'earlier than heart rate alone.',
    'today.overload':
        'Load is accumulating. Acute-to-chronic ratio is {acwr} and HRV has been below '
            'baseline for three days.',

    'sleep.title': 'Sleep',
    'sleep.lastNight': 'Last night',
    'sleep.score': 'Sleep score',
    'sleep.caption':
        '{sleep} asleep, {bed} in bed. Restorative stages (deep + REM) made up {pct}% '
            'of the night — target band 38–46%.',
    'sleep.throughNight': 'Through the night',
    'sleep.stages': 'Stage distribution',
    'sleep.components': 'Components',
    'sleep.deeper': 'Deeper',
    'sleep.last14': 'Duration · last 14 nights',
    'sleep.windowMap': 'Sleep window map',
    'sleep.need': 'need',
    'sleep.deep': 'Deep',
    'sleep.light': 'Light',
    'sleep.rem': 'REM',
    'sleep.awake': 'Awake',
    'sleep.duration': 'Duration',
    'sleep.efficiency': 'Efficiency',
    'sleep.restoration': 'Restoration',
    'sleep.continuity': 'Continuity',
    'sleep.timing': 'Timing',
    'sleep.weight': 'Weighted {w}%',
    'sleep.debt': 'Sleep debt',
    'sleep.debtSub': 'Last 14 days, older days decayed',
    'sleep.sri': 'Circadian regularity',
    'sleep.sriSub': 'How stable your sleep window is day to day',
    'sleep.cardiac': 'Nocturnal cardiac recovery',
    'sleep.cardiacSub': 'How far and how early your heart rate dropped',
    'sleep.eff': 'Sleep efficiency',
    'sleep.effSub': 'The share of time in bed spent asleep',
    'sleep.rasterNote':
        'Each row is a night, the band is time asleep, its color that night\'s sleep '
            'score. The overlap of the bands — not the hours — is what regularity measures.',

    'load.title': 'Load',
    'load.daily': 'Daily load',
    'load.caption':
        'Computed from zone-weighted heart rate minutes; the scale is logarithmic. '
            'Today {min} minutes were spent above zone 1.',
    'load.balance': 'Load balance',
    'load.acute': 'Acute load',
    'load.acuteSub': 'Last 7 days, average',
    'load.chronic': 'Chronic load',
    'load.chronicSub': 'Last 28 days, average',
    'load.ratio': 'Acute / chronic ratio',
    'load.ratioSub': '0.80–1.30 is the sustainable band',
    'load.last28': 'Last 28 days',
    'load.avg28': '28-day avg',
    'load.zones': 'Heart rate zones today',
    'load.zone': 'Zone {n}',
    'load.steps': 'Steps',
    'load.zoneNote':
        'Bar color shows that day\'s acute-to-chronic ratio: green is the tempo your '
            'body is used to; orange is the edge; red marks days you raised load faster '
            'than you had adapted to.',

    'heart.title': 'Heart and respiration',
    'heart.last45': 'Last 45 days',
    'heart.hrvTag': 'Nightly HRV (RMSSD)',
    'heart.hrvCaption':
        'The grey ribbon is ±1 standard deviation of the 14-day baseline. What matters '
            'is not one night\'s value but where it sits in the series.',
    'heart.hrvMissing':
        'Health Connect does not appear to write HRV on this device. Readiness was '
            'computed by redistributing the weights of the remaining inputs.',
    'heart.measured': 'Measured values',
    'heart.hrv': 'Heart rate variability',
    'heart.hrvSub': '{z} z against baseline',
    'heart.rhr': 'Resting heart rate',
    'heart.rhrSub': 'Lowest sustained value during sleep',
    'heart.rhrDerivedSub': 'Derived from the nightly heart rate series',
    'heart.spo2': 'Nightly SpO2',
    'heart.spo2Sub': 'Lowest {min}%',
    'heart.resp': 'Respiratory rate',
    'heart.respSub': 'Usually the first signal to move when you are ill',
    'heart.temp': 'Skin temperature deviation',
    'heart.tempSub': 'Difference from your own nightly average',
    'heart.rhrHistory': 'Resting heart rate · full history',

    'data.title': 'Data coverage',
    'data.source': 'Health Connect',
    'data.nightsWithSleep': 'Nights with a sleep record',
    'data.enoughCaption':
        'There is enough history for baselines; the scores are meaningful.',
    'data.thinCaption':
        'Baselines are built from the previous 14 nights. Until you reach that, '
            'z-scores stay near zero. Time fixes this.',
    'data.summary': 'Summary',
    'data.requested': 'Requested window',
    'data.requestedSub': 'How many days back the app asks for',
    'data.range': 'Date range of what arrived',
    'data.noRange': 'No records arrived',
    'data.hrvNights': 'Nights with HRV',
    'data.hrvNightsSub': 'Weighted 40% in readiness',
    'data.rhrDays': 'Days with resting heart rate',
    'data.rhrDaysSub': 'Weighted 25%',
    'data.rhrDerivedSub': '{n} days derived from the nightly heart rate series',
    'data.capabilities': 'Metrics that can be computed',
    'data.capReadiness': 'Readiness score',
    'data.capReadinessSub': 'Weights of the available inputs are redistributed',
    'data.capSleep': 'Sleep score and debt',
    'data.capSleepSub': 'Depends only on sleep stages',
    'data.capLoad': 'Daily load and ACWR',
    'data.capLoadSub': 'From heart rate zones and steps',
    'data.capIllness': 'Early illness signal',
    'data.capIllnessSub': 'Needs respiratory rate and skin temperature',
    'data.capSpo2': 'Nightly SpO2 tracking',
    'data.capSpo2Sub': 'Needs blood oxygen records',
    'data.byType': 'Records by type',
    'data.usedInScores': 'Used directly in the scores',
    'data.derivedNote':
        'No resting heart rate record arrives, but the nightly heart rate series does, '
            'so the value is derived from it: the lowest sustained 30-minute average of '
            'the night. It may differ slightly from what the device would write, but it '
            'is internally consistent, so baselines and z-scores work correctly.',
    'data.missingNote':
        'For types showing zero, check in order: is the device connected in the Google '
            'Health app; is Google Health allowed to write that type in Health Connect; '
            'is this app allowed to read it.',
    'data.privacyNote':
        'All reading happens on the device. No data leaves it; this screen only shows '
            'what came from the phone\'s own Health Connect store.',
    'data.export': 'Export data',
    'data.exportFailed': 'Export failed',
    'data.exportSubject': 'Kerteriz data export',

    'type.deepSleep': 'Deep sleep',
    'type.lightSleep': 'Light sleep',
    'type.remSleep': 'REM sleep',
    'type.awake': 'Awake periods',
    'type.sleepSession': 'Sleep session',
    'type.heartRate': 'Heart rate',
    'type.restingHr': 'Resting heart rate',
    'type.hrv': 'HRV (RMSSD)',
    'type.respiratory': 'Respiratory rate',
    'type.spo2': 'Blood oxygen',
    'type.skinTemp': 'Skin temperature',
    'type.steps': 'Steps',

    'legal.disclaimer':
        'This app does not diagnose and does not give medical advice. It shows your own '
            'data against your own baseline. Talk to a clinician about health decisions.',
  };
}
