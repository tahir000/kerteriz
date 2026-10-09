import 'package:flutter/widgets.dart';

/// Hafif çoklu dil katmanı.
///
/// Kod üretimi ya da ARB dosyaları yok: tek bir sınıf, iki harita.
/// Yeni dil eklemek için `_en` gibi bir harita daha yazıp `_all`'a koymak yeterli.
/// Bilinmeyen bir dil gelirse İngilizceye düşer.
/// Dile duyarlı büyük harf. Dart'ın `toUpperCase()` dili bilmiyor: Türkçe'de
/// "i" harfini "I" yapıyor ("İÇİN" yerine "IÇIN", "YÜKSELİR" yerine
/// "YÜKSELIR"). Başlıklar ve rozetler bunu kullanmalı.
String buyukHarf(String s, [String? dil]) {
  final d = dil ?? S.aktifDil;
  if (d == 'tr' || d == 'az') {
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return s.toUpperCase();
}

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

  /// Uygulamanın etkin dili; açılışta cihaz diline göre ayarlanıyor.
  static String aktifDil = 'en';

  // ---------------------------------------------------------------
  static const Map<String, String> _tr = {
    'app.name': 'Kerteriz',

    // sekmeler
    'tab.today': 'Bugün',
    'tab.sleep': 'Uyku',
    'tab.load': 'Yük',
    'tab.heart': 'Kalp',
    'tab.data': 'Veri',

    // genel
    'unit.of100': '/100',
    'unit.of21': '/21',
    'unit.ms': ' ms',
    'unit.bpm': ' atım',
    'unit.min': ' dk',
    'unit.night': ' gece',
    'unit.day': ' gün',
    'unit.record': ' kayıt',
    'unit.perMin': '/dk',
    'unit.z': ' z',
    'unit.ml': ' ml',
    'common.retry': 'Yeniden oku',
    'common.yes': 'evet',
    'common.no': 'hayır',
    'common.none': 'yok',
    'common.hourShort': 's',
    'common.minShort': 'd',

    // seviyeler
    'lvl.good': 'iyi',
    'lvl.watch': 'izlenmeli',
    'lvl.low': 'düşük',
    'lvl.ready': 'hazır',
    'lvl.medium': 'orta',
    'lvl.normal': 'normal',
    'lvl.below': 'altında',
    'lvl.wellBelow': 'belirgin altında',
    'lvl.inBand': 'bant içi',
    'lvl.borderline': 'sınırda',
    'lvl.risky': 'riskli',
    'lvl.accumulating': 'birikiyor',
    'lvl.high': 'yüksek',
    'lvl.steady': 'sabit',
    'lvl.drifting': 'kayıyor',
    'lvl.deviation': 'sapma',
    'lvl.veryRegular': 'çok düzenli',
    'lvl.variable': 'değişken',
    'lvl.irregular': 'düzensiz',
    'lvl.flowing': 'akıyor',
    'lvl.derived': 'türetildi',
    'lvl.present': 'var',
    'lvl.empty': 'boş',
    'lvl.on': 'açık',
    'lvl.off': 'kapalı',
    'lvl.working': 'çalışıyor',
    'lvl.noData': 'veri yok',
    'lvl.full': 'tam',
    'lvl.partial': 'kısmi',
    'lvl.enough': 'yeterli',
    'lvl.building': 'biriktiriyor',
    'lvl.tooFew': 'çok az',

    // durum ekranları
    'state.reading': 'Health Connect okunuyor…',
    'state.noRecords': 'Health Connect hiç kayıt döndürmedi.',
    'state.noSdk': 'Bu cihazda Health Connect yok.',
    'state.updateSdk': 'Health Connect güncellenmeli. Güncelledikten sonra tekrar dene.',
    'state.noPermission': 'Health Connect izinleri verilmedi.',
    'state.readError': 'Veri okunamadı',
    'state.noSleep': 'Dün geceye ait uyku kaydı bulunamadı.',
    'crash.eyebrow': 'Tanılama',
    'crash.title': 'Geçen açılış yarıda kaldı',
    'crash.body':
        'Uygulama bir önceki açılışta kapandı. Bu sefer Health Connect\'e hiç '
            'dokunmadan açıldı ki nerede durduğunu görebilesin. Aşağıdaki son '
            'satır, kapanmadan önce ulaşılan adımı gösterir.',
    'crash.copy': 'Kopyala',
    'crash.share': 'Paylaş',
    'crash.copied': 'İz panoya kopyalandı',
    'crash.retry': 'Yine de oku',
    'state.noScores':
        'Health Connect\'ten gelen günlerde henüz uyku ya da nabız kaydı yok. '
            'Hazırlık, uyku ve yük skorları bu ikisinden hesaplanıyor, o yüzden '
            'burada sayı göstermiyoruz. Neyin geldiğini Veri sekmesi söyler.',

    // bugün
    'today.title': 'Bugün',
    'today.today': 'bugün',
    'today.readiness': 'Hazırlık',
    'today.inputs': 'Hazırlığı oluşturan girdiler',
    'today.hrv': 'HRV',
    'today.hrvSub': 'Gece ortalama RMSSD, 14 günlük logaritmik taban çizgine göre',
    'today.rhr': 'Dinlenme nabzı',
    'today.rhrSub': 'Düşük olması iyi; işaret ters çevrilmiş',
    'today.respTemp': 'Solunum + cilt sıcaklığı',
    'today.respTempSub': 'Hastalık için en erken iki sinyal',
    'today.calibrating': 'Taban çizgin oluşuyor',
    'today.calibratingEarly':
        'Hazırlık şimdilik yalnızca uykudan hesaplanıyor. HRV ve dinlenme nabzı '
            '{min}. geceden sonra katılıyor: daha az geceyle kurulan bir taban '
            'çizgiye göre sapma ölçmek rastgele sonuç verir.',
    'today.calibratingLate':
        'HRV ve dinlenme nabzı artık skora katılıyor. Taban çizgi {full}. gecede '
            'tam oturacak; o zamana kadar sayılar biraz daha oynak olabilir.',
    'today.calibratingRow': 'Taban çizgi kuruluyor: {n}/{min} gece. Henüz skora katılmıyor',
    'today.hrvNone':
        'Health Connect\'e HRV gelmiyor. Hazırlık nabız ve uykudan kuruluyor; '
            'ayrıntı Veri sekmesinde',
    'today.rhrNone': 'Dün gece için dinlenme nabzı yok',
    'today.sleepScore': 'Uyku skoru',
    'today.weight25': 'Ağırlığı %25',
    'today.forToday': 'Bugün için',
    'today.suggestedLoad': 'Önerilen yük',
    'today.suggestedLoadSub': 'Hazırlığa göre hedef bant',
    'today.debt': 'Uyku borcu',
    'today.debtSub': 'Son 14 gün, sönümlenerek',
    'today.loadRatio': 'Yük oranı',
    'today.loadRatioSub': 'Akut / kronik',
    'today.last30': 'Son 30 gün hazırlık',
    'today.caption':
        'Dün gece {sleep} uyudun (ihtiyaç {need}). HRV {hrv} ms, dinlenme nabzı {rhr} atım.',
    'today.captionNoSleep':
        'Dün geceye ait uyku kaydı bulunamadı; hazırlık yalnızca kalp verisinden hesaplandı.',
    'today.chartNote':
        'Her sütun bir gün; renk o günün seviyesi. Renk tek başına bırakılmadı — '
            'her yerde yanında seviye etiketi ve sayının kendisi var.',
    'today.illness':
        'Vücudun bir şeyle uğraşıyor. Solunum hızı, cilt sıcaklığı ve dinlenme nabzı '
            'aynı anda taban çizginin üzerinde. Bu üçlüye birlikte bakmak, tek başına '
            'nabza bakmaktan daha erken uyarır.',
    'today.overload':
        'Yüklenme birikiyor. Akut/kronik yük oranı {acwr} ve HRV üç gündür taban '
            'çizginin altında.',

    // su
    'today.water': 'Su',
    'today.waterGoal': 'Hedef {goal} ml — ana ekran widget\'ından eklenir',
    'today.waterNote':
        'Su alımı hazırlık skoruna ağırlıkla katılmıyor. Etkisi gerçek ama bir '
            'katsayı verecek kadar net değil; onun yerine kendi verinden hesaplanan '
            'karşılaştırma aşağıda.',
    'today.waterLinkNone':
        'Karşılaştırma için hem hedefin üstünde hem altında en az dörder gün '
            'gerekiyor. Su kaydı biriktikçe bu satır dolacak.',

    // gece nabzı uyarısı
    'today.nightHrHigh':
        'Gece nabzın iki gecedir taban çizginin belirgin üstünde (ortalama '
            '+{delta} atım). Yorgunluk, alkol, geç yemek ya da başlayan bir '
            'hastalık bunu yapabilir. Teşhis değil; bugün yükü hafif tutmak '
            'için bir işaret.',

    // bu gece
    'today.tonight': 'Bu gece',
    'today.bedtime': 'Yatma saati önerisi',
    'today.bedtimeSub':
        '{wake} kalkış için · {need} ihtiyaç + {payback} borç payı · verim %{eff}',
    'today.bedtimeNote':
        'İhtiyaç bugünkü yüke göre hesaplanıyor; borcun dörtte biri (en çok bir '
            'saat) ekleniyor, çünkü borç tek gecede kapanmaz. Yatakta geçecek süre '
            'son 14 gecedeki kendi uyku verimine göre uzatıldı. Kalkış saati '
            'ayarlardan değişir.',
    'today.bedtimeNoteDefault':
        'Henüz yeterli gece yok; uyku verimi için varsayılan %90 kullanıldı. '
            'Üç geceden sonra kendi verin devreye girer. Kalkış saati ayarlardan değişir.',

    // günün cümlesi
    'headline.tone.kalibrasyon': 'Taban çizgin oluşuyor',
    'headline.tone.dinlen': 'Bugün dinlenme günü',
    'headline.tone.olculu': 'Ölçülü bir gün',
    'headline.tone.hazir': 'Yüklenmeye hazırsın',
    'headline.why.hastalik': 'solunumun ve nabzın birlikte yükseldi, kendini dinle',
    'headline.why.geceNabzi': 'gece nabzın taban çizginin {v} atım üstünde',
    'headline.why.yuklenme': 'yük oranın {v} ve HRV üç gündür düşük',
    'headline.why.kisaUyku': 'dün gece yalnızca {v} uyudun',
    'headline.why.buyukBorc': 'uyku borcun {v}',
    'headline.why.dusukHrv': 'HRV\'n her zamankinden düşük',
    'headline.why.yuksekHrv': 'HRV\'n her zamankinden yüksek',
    'headline.why.iyiUyku': 'dün gece iyi uyudun ({v} puan)',
    'headline.bed': 'Bu gece hedef yatış {bed}.',
    'today.weekShort': 'hazırlık {r}',

    // senin verin ne diyor
    'insights.section': 'Kendi verin',
    'insights.title': 'Senin verin ne diyor',
    'insights.entry': '{n} karşılaştırma hazır',
    'insights.entryNone': 'Veri biriktikçe karşılaştırmalar burada açılacak',
    'insights.intro':
        'Burada skor yok; kendi gecelerinin birbiriyle karşılaştırması var. Her '
            'kartta iki grup gün, her grubun ortalaması ve kaç günden hesaplandığı '
            'yazıyor. Her iki grupta en az dört gün yoksa kart gösterilmiyor.',
    'insights.tags': 'Etiketlerin',
    'insights.tagSub': 'Ertesi sabahki hazırlık ortalaması',
    'insights.tagWith': 'İşaretlediğin akşamların ertesi',
    'insights.tagWithout': 'İşaretlemediğin akşamların ertesi',
    'insights.tagResult': 'Fark {delta} puan.',
    'insights.water.title': 'Su hedefi',
    'insights.water.sub': 'Hedef {goal} ml · ertesi sabahki hazırlık ortalaması',
    'insights.water.a': 'Hedefi tutturduğun günlerin ertesi',
    'insights.water.b': 'Hedefin altında kaldığın günlerin ertesi',
    'insights.auto': 'Kendiliğinden çıkanlar',
    'insights.autoNone':
        'Bu karşılaştırmalar etiket istemez, verinin kendisinden çıkar. Birkaç '
            'hafta veri birikince burada görünecekler.',
    'insights.caveat':
        'Bunlar ilişki, neden değil. Erken yattığın geceler başka açılardan da '
            'farklı olabilir (hafta sonu, stres, yemek). Gün sayısı az olan '
            'farklara temkinli bak.',
    'insights.erkenYatis.title': 'Erken yatmak',
    'insights.erkenYatis.sub': 'Senin her zamanki yatış saatin {saat} · o sabahki hazırlık',
    'insights.erkenYatis.a': '{saat}\'ten önce yattığın geceler',
    'insights.erkenYatis.b': '{saat}\'ten sonra yattığın geceler',
    'insights.erkenYatis.result': 'Erken yattığın sabahlar hazırlık farkı {delta} puan.',
    'insights.yukluGun.title': 'Yüklü günler',
    'insights.yukluGun.sub': 'Ertesi sabah HRV, kendi taban çizgine göre',
    'insights.yukluGun.a': 'Yükü {esik} üstü günlerin ertesi',
    'insights.yukluGun.b': 'Yükü {esik} ve altı günlerin ertesi',
    'insights.yukluGun.result':
        'Fark {delta} z. Eksi, yüklü günlerden sonra HRV\'nin düştüğü anlamına gelir.',
    'insights.adim.title': 'Çok yürüdüğün günler',
    'insights.adim.sub': 'O gecenin uyku skoru',
    'insights.adim.a': '{esik} adım üstü günlerin gecesi',
    'insights.adim.b': '{esik} adım ve altı günlerin gecesi',
    'insights.adim.result': 'Fark {delta} puan.',
    'insights.sekerleme.title': 'Şekerleme',
    'insights.sekerleme.sub': 'O gecenin uyku süresi',
    'insights.sekerleme.a': 'Şekerleme yaptığın günlerin gecesi',
    'insights.sekerleme.b': 'Şekerleme yapmadığın günlerin gecesi',
    'insights.sekerleme.result': 'Fark {delta}.',

    // hatırlatma
    'tags.remind': 'Her akşam yatma saatinden önce hatırlat',
    'notif.channel': 'Akşam hatırlatması',
    'notif.channelSub': 'Yatma saatinden yarım saat önce, günde bir kez',
    'notif.title': 'Yatma vaktine yarım saat: {bed}',
    'notif.body': 'Bu akşam neler oldu? Etiketlemek tek dokunuş.',
    'notif.denied': 'Bildirim izni verilmedi. Telefonun ayarlarından açabilirsin.',
    'notif.enabled': 'Her akşam yatma saatinden yarım saat önce hatırlatacağım.',
    'settings.reminder': 'Akşam hatırlatması',
    'settings.reminderSub':
        'Yatma saatinden yarım saat önce tek bildirim; dokununca etiket günlüğü açılır. '
            'Saat her açılışta yeniden hesaplanır.',
    'settings.reminderOff': 'Kapalı',
    'settings.reminderOn': 'Açık',

    // gün içi
    'lvl.calm': 'sakin',
    'intraday.section': 'Gün içi',
    'intraday.title': 'Gün içi',
    'intraday.energy': 'Enerji',
    'intraday.energySub': 'Sabah {start} ile başladı · {time} itibarıyla tahmin',
    'intraday.stress': 'Stres',
    'intraday.stressSub': 'Son bir saat · bugün {min} yüksek stres',
    'intraday.none': 'Bugün için henüz gün içi nabız verisi yok. Bileklik eşitledikçe dolacak.',
    'intraday.energyStart': 'Başlangıç',
    'intraday.energyStartSub': 'Sabahki hazırlık (ilk haftalarda uyku skoru)',
    'intraday.drainLoad': 'Hareket ve antrenman',
    'intraday.drainStress': 'Stres',
    'intraday.drainAwake': 'Uyanık geçen saatler',
    'intraday.energyNote':
        'Enerji bir tahmin, ölçüm değil. Sabah hazırlıkla başlıyor; günlük yükle aynı '
            'nabız bölgeleri, hareketsizken yükselen nabız ve uyanık geçen her saat onu '
            'azaltıyor. Katsayılar sabit: en ağır bir gün yaklaşık 60 puan, tam stresli '
            'bir saat 6 puan, uyanık her saat 1,5 puan götürüyor.',
    'intraday.stressHourly': 'Saat saat stres',
    'intraday.stressNone': 'Bugün stres ölçülebilecek kadar hareketsiz uyanık dilim yok.',
    'intraday.highStress': 'Yüksek stres süresi',
    'intraday.calmHr': 'Sakin nabzın',
    'intraday.calmHrSub': 'Son günlerin hareketsiz uyanık anlarından; stresin referansı',
    'intraday.stressNote':
        'Stres, hareket etmezken nabzın kendi sakin nabzının üstüne çıkması. Yürürken, '
            'antrenmanda ve uykuda geçen dilimler sayılmıyor. Kahve, sıcak, hastalık ve '
            'heyecan da nabzı yükseltir; bu yüzden "stres" burada zihinsel stresle sınırlı '
            'değil, vücudun yüklenmesi demek.',

    // sabah sorusu
    'feel.title': 'Bugün nasıl hissediyorsun?',
    'feel.sub': 'Tek dokunuş. Hissin ile hazırlık skorunu karşılaştırıyoruz.',
    'feel.1': 'Çok yorgun',
    'feel.2': 'Yorgun',
    'feel.3': 'Normal',
    'feel.4': 'İyi',
    'feel.5': 'Çok iyi',
    'feel.section': 'Hissin ve skorun',
    'feel.waiting':
        'İyi hissettiğin (İyi, Çok iyi) ve kötü hissettiğin (Yorgun, Çok yorgun) en az '
            'dörder sabah gerekiyor. Şimdiye kadar {n} sabah işaretlendi.',
    'feel.compareTitle': 'Skor seni tanıyor mu?',
    'feel.compareSub': 'O sabahki hazırlık ortalaması',
    'feel.good': 'İyi hissettiğin sabahlar',
    'feel.bad': 'Yorgun hissettiğin sabahlar',
    'feel.resultMatch': 'Fark {delta} puan: skor hissinle belirgin biçimde örtüşüyor.',
    'feel.resultWeak': 'Fark {delta} puan: aynı yönde ama zayıf. Sabah sayısı arttıkça netleşir.',
    'feel.resultNone':
        'Fark {delta} puan: skor şimdilik hissinle örtüşmüyor. Uyku dışı etkenler '
            '(stres, hastalık, alkol) hissini skordan daha çok etkiliyor olabilir.',

    // antrenmanlar
    'type.workout': 'Antrenman',
    'workout.section': 'Antrenmanlar',
    'workout.none':
        'Son 14 günde antrenman kaydı yok. Bileklik ya da spor uygulaması antrenmanı '
            'Health Connect\'e yazınca burada görünür. Egzersiz iznini vermediysen '
            'Health Connect ayarlarından açabilirsin.',
    'workout.rowSub': '{date} {time} · {dur} · ort. {hr} atım',
    'workout.load': 'Antrenman yükü',
    'workout.share': 'Günün yükünün %{p}\'i',
    'workout.hr': 'Ortalama nabız',
    'workout.hrSub': 'En yüksek {max} atım',
    'workout.kcal': 'Kalori',
    'workout.distance': 'Mesafe',
    'workout.nextMorning': 'Ertesi sabah hazırlık',
    'workout.nextHrv': 'HRV {z} z',
    'workout.note':
        'Antrenman yükü günlük yükle aynı formülle, o saatlerin dakikalık nabzından '
            'hesaplanıyor; 0-21 ölçeği de aynı. Kalori ve mesafe antrenmanı kaydeden '
            'uygulamanın kendi değeri.',

    // sabah bildirimi
    'notif.morningChannel': 'Sabah bildirimi',
    'notif.morningChannelSub': 'Kalkış saatinden yarım saat sonra, günde bir kez',
    'notif.morningTitle': 'Günaydın, gecen hazır',
    'notif.morningBody': 'Hazırlığını gör ve bugün nasıl hissettiğini tek dokunuşla işaretle.',
    'settings.morning': 'Sabah bildirimi',
    'settings.morningSub':
        'Kalkış saatinden yarım saat sonra tek bildirim. Skoru içermiyor: o saatte gecenin '
            'verisi henüz işlenmedi, skor uygulama açılınca hesaplanıyor.',
    'workout.type.RUNNING': 'Koşu',
    'workout.type.RUNNING_TREADMILL': 'Koşu bandı',
    'workout.type.WALKING': 'Yürüyüş',
    'workout.type.HIKING': 'Doğa yürüyüşü',
    'workout.type.BIKING': 'Bisiklet',
    'workout.type.BIKING_STATIONARY': 'Sabit bisiklet',
    'workout.type.SWIMMING': 'Yüzme',
    'workout.type.SWIMMING_POOL': 'Havuzda yüzme',
    'workout.type.SWIMMING_OPEN_WATER': 'Açık suda yüzme',
    'workout.type.STRENGTH_TRAINING': 'Kuvvet antrenmanı',
    'workout.type.TRADITIONAL_STRENGTH_TRAINING': 'Ağırlık antrenmanı',
    'workout.type.FUNCTIONAL_STRENGTH_TRAINING': 'Fonksiyonel antrenman',
    'workout.type.WEIGHTLIFTING': 'Ağırlık kaldırma',
    'workout.type.HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
    'workout.type.YOGA': 'Yoga',
    'workout.type.PILATES': 'Pilates',
    'workout.type.ELLIPTICAL': 'Eliptik',
    'workout.type.ROWING': 'Kürek',
    'workout.type.ROWING_MACHINE': 'Kürek makinesi',
    'workout.type.FOOTBALL_SOCCER': 'Futbol',
    'workout.type.SOCCER': 'Futbol',
    'workout.type.BASKETBALL': 'Basketbol',
    'workout.type.TENNIS': 'Tenis',
    'workout.type.DANCING': 'Dans',
    'workout.type.OTHER': 'Antrenman',

    // döngü
    'cycle.title': 'Döngü',
    'cycle.day': '{n}. gün',
    'cycle.phase.regl': 'Regl dönemi',
    'cycle.phase.folikuler': 'Foliküler evre',
    'cycle.phase.luteal': 'Luteal evre: nabız yükselir, HRV düşer',
    'cycle.note':
        'Döngü günü, takvimde işaretlediğin günlerden ve Health Connect\'teki regl '
            'kayıtlarından (Flo, Clue, Samsung Health gibi uygulamalar yazıyor) hesaplanıyor. Evre kaba bir tahmin: yumurtlama '
            'döngü sonundan yaklaşık 14 gün önce varsayılıyor. Kerteriz döngü ya da '
            'doğurganlık takibi yapmıyor.',
    'cycle.noAdjust':
        'Hazırlık şimdilik döngüye göre düzeltilmiyor: kendi farkını ölçmek için en az '
            'iki döngü başlangıcı ve her evrede sekiz gün veri gerekiyor.',
    'cycle.diff':
        'Senin verinde luteal evrede dinlenme nabzın ortalama {rhr} atım, HRV\'n %{hrv} '
            'değişiyor. Bu fark sabit bir katsayı değil, kendi geçmiş döngülerinden.',
    'cycle.adjustedToday':
        'Bugün luteal evredesin; hazırlık hesaplanırken nabız ve HRV bu fark kadar '
            'düzeltildi, yani beklenen yükseliş seni "dinlen"e itmiyor.',
    'cycle.notLuteal': 'Bugün luteal evrede değilsin; düzeltme uygulanmadı.',

    // cihaz notu
    'device.title': '{src} HRV paylaşmıyor',
    'device.titleGeneric': 'Cihazın HRV paylaşmıyor',
    'device.body':
        'Health Connect\'e kalp hızı değişkenliği gelmiyor. Hazırlık dinlenme nabzı ve '
            'uykudan kuruluyor; gece toparlanması yeterli veri birikince eklenecek.',
    'device.bodyCardiac':
        'Health Connect\'e kalp hızı değişkenliği gelmiyor. Hazırlık dinlenme nabzı, '
            'uyku ve gece kardiyak toparlanmasından kuruluyor. Skorun en ağır girdisi eksik; '
            'sayıları HRV\'li cihazlarla birebir karşılaştırma.',
    'data.sources': 'Veri kaynakları',
    'data.sourcesNoHrv':
        'Samsung Health ve Garmin Connect, Health Connect\'e HRV yazmıyor (Samsung dinlenme '
            'nabzı ve solunumu da yazmıyor). Kerteriz dinlenme nabzını gece nabız serisinden '
            'türetiyor; HRV\'nin yerine gece kardiyak toparlanmasını kullanıyor.',
    'type.menstruation': 'Regl kaydı',
    'type.nutrition': 'Beslenme',

    // beslenme karşılaştırmaları
    'insights.gecYemek.title': 'Geç yemek',
    'insights.gecYemek.sub': 'Son öğünden yatışa senin medyanın {h} saat · o geceki uyku skoru',
    'insights.gecYemek.a': 'Yatıştan {h} saatten az önce yediğin geceler',
    'insights.gecYemek.b': 'Daha erken yediğin geceler',
    'insights.gecYemek.result': 'Fark {delta} puan.',
    'insights.kalori.title': 'Çok kalorili günler',
    'insights.kalori.sub': 'Ertesi sabahki hazırlık',
    'insights.kalori.a': '{kcal} kcal üstü günlerin ertesi',
    'insights.kalori.b': '{kcal} kcal ve altı günlerin ertesi',
    'insights.kalori.result': 'Fark {delta} puan.',
    'insights.kafein.title': 'Öğleden sonra kafein',
    'insights.kafein.sub': 'O geceki uyku skoru',
    'insights.kafein.a': '14:00\'ten sonra kafein aldığın günler',
    'insights.kafein.b': 'Kafeini 14:00\'ten önce bitirdiğin günler',
    'insights.kafein.result': 'Fark {delta} puan.',

    // döngü sekmesi ve cinsiyet
    'tab.cycle': 'Döngü',
    'unit.daysN': '{n} gün',
    'cycle.screenTitle': 'Döngü',
    'cycle.phaseNote.regl':
        'Regl dönemi. Bu günlerde nabız ve HRV genelde döngünün başındaki seviyesine döner.',
    'cycle.phaseNote.folikuler':
        'Foliküler evre. Çoğu kişide dinlenme nabzı en düşük, HRV en yüksek bu dönemde olur.',
    'cycle.phaseNote.luteal':
        'Luteal evre. Dinlenme nabzı yükselir, HRV düşer; bu beklenen bir değişim, '
            'toparlanamadığın anlamına gelmiyor.',
    'cycle.thisCycle': 'Bu döngü',
    'cycle.next': 'Sonraki regl',
    'cycle.nextSub': 'Kendi ortalama döngü uzunluğuna göre kaba tahmin',
    'cycle.inDays': '~{n} gün',
    'cycle.anyDay': 'her an',
    'cycle.length': 'Döngü uzunluğu',
    'cycle.lengthSub': 'Son {n} döngünün medyanı; veri yoksa 28 gün',
    'cycle.adjust': 'Bugün hazırlık düzeltildi mi',
    'cycle.adjustOff': 'Döngü düzeltmesi ayarlardan kapatıldı.',
    'cycle.yourShift': 'Luteal evredeki kayman',
    'cycle.shiftSub': 'Luteal günlerin foliküler günlere göre ortalama farkı, senin verinden',
    'cycle.rhrChart': 'Son 8 hafta dinlenme nabzı',
    'cycle.calendar': 'Regl günleri',
    'cycle.calendarNote':
        'Günlere dokunarak regl olarak işaretle. İşaretler yalnızca telefonunda tutulur, '
            'Health Connect\'e yazılmaz. Çerçeveli günler Health Connect\'ten (Flo, Clue, '
            'Samsung Health gibi uygulamalardan) geliyor; onları o uygulamadan değiştir.',
    'cycle.recent': 'Son döngüler',
    'cycle.current': 'Devam ediyor',
    'cycle.emptyTitle': 'Döngü henüz bilinmiyor',
    'cycle.emptyBody':
        'Aşağıdaki takvimden regl günlerini işaretleyebilir ya da Flo, Clue, Samsung Health '
            'gibi bir uygulamanın Health Connect\'e yazdığı kayıtları okumama izin verebilirsin.',
    'cycle.grant': 'Regl kayıtlarını okumaya izin ver',
    'cycle.periodDay': 'regl günü',
    'cycle.fromHc': 'Bu gün Health Connect\'ten geliyor; kaydı yazan uygulamadan değiştirebilirsin.',
    'settings.sex': 'Cinsiyet',
    'settings.sexFemale': 'Kadın',
    'settings.sexMale': 'Erkek',
    'settings.sexNone': 'Belirtme',
    'settings.sexSub':
        'Hiçbir skora girmiyor. Kadın seçilince Döngü sekmesi ve aşağıdaki döngü ayarları '
            'açılıyor. Seçim yalnızca telefonunda tutulur.',
    'settings.cycle': 'Döngü',
    'settings.cyclePermission': 'Health Connect regl kayıtları',
    'settings.cyclePermissionOn': 'Okunuyor',
    'settings.cyclePermissionOff': 'İzin yok; dokun ve izin ver. Takvimden işaretleme izinsiz de çalışır.',
    'settings.cycleAdjust': 'Hazırlığı döngüye göre düzelt',
    'settings.cycleNote':
        'Açıkken luteal evrede nabız ve HRV, kendi geçmiş döngülerinde ölçülen fark kadar '
            'düzeltilerek hazırlık hesaplanır. Yeterli döngü verisi yoksa düzeltme yapılmaz.',

    'cycle.phaseShort.regl': 'Regl',
    'cycle.phaseShort.folikuler': 'Foliküler',
    'cycle.phaseShort.luteal': 'Luteal',
    'cycle.lengthNone': 'Henüz tam bir döngü yok; {n} gün varsayıldı',
    'cycle.adjustWaiting': 'Henüz değil: kendi kaymanı ölçecek kadar döngü verisi yok',
    'cycle.progressStarts': 'Döngü başlangıcı',
    'cycle.progressLuteal': 'Luteal evrede ölçülen gün',
    'cycle.progressFollicular': 'Foliküler evrede ölçülen gün',
    'cycle.progressDone': 'tamam',
    'cycle.progressNote':
        'Üçü de dolunca luteal evredeki nabız ve HRV kayman senin verinden ölçülür ve '
            'hazırlık ona göre düzeltilir. Regl günlerini takvimden işaretlemek döngü '
            'başlangıçlarını sayar.',

    // etiket günlüğü
    'tags.title': 'Bu akşam',
    'tags.sub': 'Tek dokunuş. Ertesi sabahki hazırlıkla karşılaştırılır.',
    'tags.none': 'Hiçbiri',
    'tag.alkol': 'Alkol',
    'tag.kafein': 'Geç kafein',
    'tag.gecYemek': 'Geç yemek',
    'tag.stres': 'Yoğun stres',
    'tag.gecAntrenman': 'Geç antrenman',
    'tags.waiting':
        'Bir etiketin etkisini göstermek için hem o etiketin olduğu hem olmadığı '
            'en az dörder akşam gerekiyor. Şimdiye kadar {n} akşam işaretlendi. '
            'Hiçbir şey yoksa "Hiçbiri"ne dokun: işaretlenmeyen akşamlar sayılmaz.',

    // haftalık özet
    'today.week': 'Haftalık özet',
    'today.weekReadiness': 'Ortalama hazırlık',
    'today.weekNights': 'Son 7 gün, {n} gece',
    'today.weekVsPrev': 'Önceki hafta {prev} · fark {delta}',
    'today.weekSleep': 'Ortalama uyku',
    'today.weekSleepScore': 'Uyku skoru ortalaması {score}',
    'today.weekSleepVsPrev': 'Uyku skoru {score} · önceki haftaya göre {delta}',
    'today.weekBest': 'En iyi gece',
    'today.weekBestSub': '{date} · {sleep} uyku',
    'today.weekDebt': 'Borç değişimi',
    'today.weekDebtSub': 'Bir hafta önce {ago}',
    'today.weekDebtUp': 'Artıyor',
    'today.weekDebtDown': 'Azalıyor',
    'today.weekDebtFlat': 'Sabit',

    // uyku
    'sleep.title': 'Uyku',
    'sleep.lastNight': 'Dün gece',
    'sleep.score': 'Uyku skoru',
    'sleep.caption':
        '{sleep} uyku, {bed} yatakta. Onarıcı evreler (derin + REM) gecenin %{pct}\'i '
            '— hedef bant %38–46.',
    'sleep.throughNight': 'Gece boyunca',
    'sleep.stages': 'Evre dağılımı',
    'sleep.components': 'Bileşenler',
    'sleep.deeper': 'Daha derin',
    'sleep.last14': 'Son 14 gecenin süresi',
    'sleep.windowMap': 'Uyku penceresi haritası',
    'sleep.need': 'ihtiyaç',
    'sleep.deep': 'Derin',
    'sleep.light': 'Hafif',
    'sleep.rem': 'REM',
    'sleep.awake': 'Uyanık',
    'sleep.duration': 'Süre',
    'sleep.efficiency': 'Verim',
    'sleep.restoration': 'Onarım',
    'sleep.continuity': 'Kesintisizlik',
    'sleep.timing': 'Zamanlama',
    'sleep.weight': 'Ağırlık %{w}',
    'sleep.debt': 'Uyku borcu',
    'sleep.debtSub': 'Son 14 gün, eski günler sönümlenerek',
    'sleep.sri': 'Sirkadiyen düzenlilik',
    'sleep.sriSub': 'Uyku pencerem günden güne ne kadar sabit',
    'sleep.cardiac': 'Gece kardiyak toparlanma',
    'sleep.cardiacSub': 'Nabzın ne kadar ve ne kadar erken düştüğü',
    'sleep.eff': 'Uyku verimi',
    'sleep.effSub': 'Yatakta geçen sürenin uykuya dönen kısmı',
    'sleep.rasterNote':
        'Her satır bir gece, bant uykuda geçtiğin süre; rengi o gecenin uyku skoru. '
            'Bantların üst üste binmesi — saatlerin değil — sirkadiyen düzenliliğin ölçüsüdür.',

    // yük
    'load.title': 'Yük',
    'load.daily': 'Günlük yük',
    'load.caption':
        'Bölge ağırlıklı nabız dakikalarından hesaplanır; ölçek logaritmiktir. '
            'Bugün {min} dakikan bölge 1 üstünde geçti.',
    'load.balance': 'Yük dengesi',
    'load.acute': 'Akut yük',
    'load.acuteSub': 'Son 7 gün ortalaması',
    'load.chronic': 'Kronik yük',
    'load.chronicSub': 'Son 28 gün ortalaması',
    'load.ratio': 'Akut / kronik oranı',
    'load.ratioSub': '0.80–1.30 arası sürdürülebilir bant',
    'load.ratioWaiting':
        '28 günlük kronik pencere henüz dolmadı; oran olduğundan büyük çıkar',
    'load.last28': 'Son 28 gün',
    'load.avg28': '28 gün ort.',
    'load.zones': 'Bugünün nabız bölgeleri',
    'load.zone': 'Bölge {n}',
    'load.steps': 'Adım',
    'load.zoneNote':
        'Sütunun rengi o günün akut/kronik oranını gösterir: yeşil, vücudunun alıştığı '
            'tempo; turuncu sınır; kırmızı, yükü alıştığından hızlı artırdığın günler.',

    // kalp
    'heart.title': 'Kalp ve solunum',
    'heart.last45': 'Son 45 gün',
    'heart.hrvTag': 'Gece HRV (RMSSD)',
    'heart.hrvCaption':
        'Gri şerit, 14 günlük taban çizginin ±1 standart sapması. Önemli olan tek '
            'gecenin değeri değil, serideki konumun.',
    'heart.hrvMissing':
        'Health Connect bu cihazda HRV yazmıyor görünüyor. Hazırlık skoru, kalan '
            'girdilerin ağırlıkları yeniden dağıtılarak hesaplandı.',
    'heart.measured': 'Ölçülen değerler',
    'heart.noValue': 'Bu cihazdan kayıt gelmiyor',
    'heart.hrv': 'Kalp hızı değişkenliği',
    'heart.hrvSub': 'Taban çizgiye göre {z} z',
    'heart.rhr': 'Dinlenme nabzı',
    'heart.rhrSub': 'Uyku sırasındaki en düşük kararlı değer',
    'heart.rhrDerivedSub': 'Gece nabız serisinden türetildi',
    'heart.spo2': 'Gece SpO2',
    'heart.spo2Sub': 'En düşük {min}%',
    'heart.resp': 'Solunum hızı',
    'heart.respSub': 'Hastalıkta genelde ilk kıpırdayan sinyal',
    'heart.temp': 'Cilt sıcaklığı sapması',
    'heart.tempSub': 'Kendi gece ortalamandan fark',
    'heart.rhrHistory': 'Dinlenme nabzı · tüm geçmiş',

    // veri
    'data.title': 'Veri kapsamı',
    'data.source': 'Health Connect',
    'data.nightsWithSleep': 'Uyku kaydı olan gece',
    'data.enoughCaption': 'Taban çizgiler için yeterli geçmiş var; skorlar anlamlı.',
    'data.thinCaption':
        'Taban çizgiler önceki 14 gecenin ortalamasından kuruluyor. O sayıya '
            'ulaşana kadar z-skorları sıfıra yakın kalır. Bekleyerek düzelir.',
    'unit.year': 'yaş',
    'unit.step': 'adım',
    'unit.kcal': 'kcal',
    'unit.km': 'km',
    'settings.personal': 'Kişisel',
    'settings.age': 'Yaş',
    'settings.ageSub': 'Tahmini maksimum nabız: {hr} atım/dk',
    'settings.ageNote':
        'Nabız bölgeleri ve günlük yük hesabı yaşa bağlı (208 - 0,7 x yaş). '
        'Yaşı değiştirince veriler yeniden işlenir.',
    'settings.wake': 'Kalkış saati',
    'settings.wakeSub': 'Yatma saati önerisi buna göre hesaplanır',
    'settings.goals': 'Günlük hedefler',
    'settings.waterGoal': 'Su hedefi',
    'settings.waterGoalSub': 'Bugün ekranındaki ölçek ve su widget\'ı',
    'settings.waterServing': 'Su porsiyonu',
    'settings.waterServingSub': 'Widget düğmesine her basışta eklenen miktar',
    'settings.stepGoal': 'Adım',
    'settings.ringSub': 'Ana ekran özet widget\'ındaki halka',
    'settings.calorieGoal': 'Kalori (toplam)',
    'settings.calorieGoalSub': 'Bazal dahil günlük toplam',
    'settings.activeCalorieGoal': 'Kalori (aktif)',
    'settings.activeCalorieGoalSub':
        'Cihaz yalnızca aktif kalori yazıyorsa bu hedef kullanılır',
    'settings.distanceGoal': 'Mesafe',
    'settings.goalsNote':
        'Hedefler skorlara girmez, yalnızca ölçekleri ve halkaları belirler. '
        'Değişiklik widget\'lara bir sonraki yenilemede yansır.',
    'settings.title': 'Ayarlar',
    'settings.about': 'Hakkında',
    'settings.dataTabSub':
        'Health Connect\'ten gerçekte ne geldiğini görmek için Veri sekmesine bak: '
        'hangi ölçüm kaç kayıt getirmiş, hangisi boş, orada yazıyor.',
    'settings.appearance': 'Görünüm',
    'settings.themeSystem': 'Sistem',
    'settings.themeLight': 'Açık',
    'settings.themeDark': 'Koyu',
    'settings.themeSub':
        'Sistem seçiliyse telefonun gece modu izlenir. Seçim kaydedilir.',
    'data.summary': 'Özet',
    'data.timedOut':
        'Şu tipler zamanında yanıt vermedi ve beklemeyi kestik: {list}. '
            'Health Connect bazen tek bir tipte takılıyor; yeniden okumayı dene.',
    'data.version': 'Uygulama sürümü',
    'data.versionSub': 'Telefonda çalışan yapı',
    'data.requested': 'İstenen aralık',
    'data.requestedSub': 'Uygulamanın geriye doğru sorduğu gün sayısı',
    'data.lastFullRead': 'Son tam okuma',
    'data.lastFullReadSub':
        'Aşağıdaki sayılar o okumadan geliyor. Açılışta yalnızca son birkaç '
        'gün tazeleniyor, gerisi önbellekten okunuyor.',
    'data.fullRead': '90 günü baştan oku',
    'data.range': 'Gelen kaydın tarih aralığı',
    'data.noRange': 'Hiç kayıt gelmedi',
    'data.hrvNights': 'HRV olan gece',
    'data.hrvNightsSub': 'Hazırlık skorunda ağırlığı %40',
    'data.rhrDays': 'Dinlenme nabzı olan gün',
    'data.rhrDaysSub': 'Ağırlığı %25',
    'data.rhrDerivedSub': '{n} günü gece nabız serisinden türetildi',
    'data.capabilities': 'Hesaplanabilen metrikler',
    'data.capReadiness': 'Hazırlık skoru',
    'data.capReadinessSub': 'Gelen girdilerin ağırlıkları yeniden dağıtılır',
    'data.capSleep': 'Uyku skoru ve borcu',
    'data.capSleepSub': 'Yalnızca uyku evrelerine bağlı',
    'data.capLoad': 'Günlük yük ve ACWR',
    'data.capLoadSub': 'Nabız bölgeleri ve adımdan',
    'data.capIllness': 'Hastalık erken uyarısı',
    'data.capIllnessSub': 'Solunum hızı ve cilt sıcaklığı gerekiyor',
    'data.capIllnessNightHr':
        'Solunum ve sıcaklık gelmiyor; yalnızca gece nabzına bakan sade sürüm çalışıyor',
    'data.capReadinessNoHrv':
        'HRV gelmiyor. Skorun %40\'ı eksik; nabız, uyku ve gece toparlanmasından kuruluyor',
    'data.capSpo2': 'Gece SpO2 takibi',
    'data.capSpo2Sub': 'Kandaki oksijen kaydı gerekiyor',
    'data.byType': 'Tip tip gelen kayıt',
    'data.usedInScores': 'Skorlarda doğrudan kullanılıyor',
    'data.derivedNote':
        'Dinlenme nabzı kaydı gelmiyor ama gece nabız serisi geliyor, bu yüzden değer '
            'seriden türetiliyor: gecenin en düşük 30 dakikalık kararlı ortalaması. '
            'Cihazın yazdığı değerden biraz farklı çıkabilir, ama kendi içinde tutarlı '
            'olduğu için taban çizgi ve z-skoru doğru çalışır.',
    'data.missingNote':
        'Sıfır görünen tipler için sırasıyla şunlara bak: Google Health uygulamasında '
            'cihaz bağlı mı; Health Connect ekranında Google Health bu tipi yazmaya '
            'yetkili mi; bu uygulama o tipi okumaya yetkili mi.',
    'data.privacyNote':
        'Bütün okuma cihazda yapılıyor. Hiçbir veri dışarı çıkmıyor; bu ekran da '
            'yalnızca telefonun kendi Health Connect deposundan ne geldiğini gösteriyor. '
            'Uygulamanın yazdığı tek şey senin eklediğin su kaydı — o da yine '
            'telefonun kendi deposuna yazılıyor.',
    'data.export': 'Veriyi dışa aktar',
    'data.exportFailed': 'Dışa aktarılamadı',
    'data.exportSubject': 'Kerteriz veri dışa aktarımı',

    // veri tipleri
    'type.deepSleep': 'Derin uyku',
    'type.lightSleep': 'Hafif uyku',
    'type.remSleep': 'REM uykusu',
    'type.awake': 'Uyanık dönemler',
    'type.sleepSession': 'Uyku oturumu',
    'type.heartRate': 'Nabız',
    'type.restingHr': 'Dinlenme nabzı',
    'type.hrv': 'HRV (RMSSD)',
    'type.respiratory': 'Solunum hızı',
    'type.spo2': 'Kandaki oksijen',
    'type.skinTemp': 'Cilt sıcaklığı',
    'type.steps': 'Adım',
    'type.water': 'Su',

    // yasal
    'legal.disclaimer':
        'Bu uygulama teşhis koymaz ve tıbbi tavsiye vermez. Kendi verini kendi taban '
            'çizgine göre gösterir. Sağlıkla ilgili kararlar için bir hekime danış.',
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
    'unit.ml': ' ml',
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
    'crash.eyebrow': 'Diagnostics',
    'crash.title': 'The last start did not finish',
    'crash.body':
        'The app closed during its previous start. This time it opened without '
            'touching Health Connect so you can see where it stopped. The last '
            'line below is the step it reached before closing.',
    'crash.copy': 'Copy',
    'crash.share': 'Share',
    'crash.copied': 'Trace copied to the clipboard',
    'crash.retry': 'Read anyway',
    'state.noScores':
        'The days coming from Health Connect carry no sleep or heart rate records '
            'yet. Readiness, sleep and load are computed from those two, so no '
            'numbers are shown here. The Data tab shows what is arriving.',

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
    'today.calibrating': 'Building your baseline',
    'today.calibratingEarly':
        'For now readiness comes from sleep alone. HRV and resting heart rate join '
            'after night {min}: measuring deviation from a baseline built on fewer '
            'nights gives random results.',
    'today.calibratingLate':
        'HRV and resting heart rate now count toward the score. The baseline settles '
            'fully on night {full}; until then numbers may move a little more.',
    'today.calibratingRow': 'Building baseline: {n}/{min} nights. Not in the score yet',
    'today.hrvNone':
        'No HRV is reaching Health Connect. Readiness is built from heart rate and '
            'sleep; details in the Data tab',
    'today.rhrNone': 'No resting heart rate for last night',
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

    // hydration
    'today.water': 'Hydration',
    'today.waterGoal': 'Goal {goal} ml — added from the home screen widget',
    'today.waterNote':
        'Hydration carries no weight in the readiness score. The effect is real but '
            'not sharp enough to justify a coefficient; what you see below is a '
            'comparison computed from your own data instead.',
    'today.waterLinkNone':
        'The comparison needs at least four days on each side of the goal. '
            'This line fills in as hydration records accumulate.',

    // night heart rate alert
    'today.nightHrHigh':
        'Your overnight heart rate has been clearly above baseline for two nights '
            '(+{delta} bpm on average). Fatigue, alcohol, a late meal or an oncoming '
            'illness can all do this. Not a diagnosis; a sign to keep today light.',

    // tonight
    'today.tonight': 'Tonight',
    'today.bedtime': 'Suggested bedtime',
    'today.bedtimeSub':
        'To wake at {wake} · {need} need + {payback} debt share · efficiency {eff}%',
    'today.bedtimeNote':
        'Need follows today\'s load; a quarter of your sleep debt (at most an hour) '
            'is added, since debt is not repaid in one night. Time in bed is stretched '
            'by your own sleep efficiency over the last 14 nights. Change the wake '
            'time in settings.',
    'today.bedtimeNoteDefault':
        'Not enough nights yet; a default 90% sleep efficiency is used. Your own '
            'data takes over after three nights. Change the wake time in settings.',

    // headline
    'headline.tone.kalibrasyon': 'Building your baseline',
    'headline.tone.dinlen': 'A rest day',
    'headline.tone.olculu': 'A measured day',
    'headline.tone.hazir': 'Ready to push',
    'headline.why.hastalik': 'respiration and heart rate are up together, listen to your body',
    'headline.why.geceNabzi': 'overnight heart rate is {v} bpm above baseline',
    'headline.why.yuklenme': 'load ratio is {v} and HRV has been low for three days',
    'headline.why.kisaUyku': 'you slept only {v} last night',
    'headline.why.buyukBorc': 'sleep debt is {v}',
    'headline.why.dusukHrv': 'HRV is lower than usual',
    'headline.why.yuksekHrv': 'HRV is higher than usual',
    'headline.why.iyiUyku': 'you slept well last night ({v} points)',
    'headline.bed': 'Tonight, aim for bed at {bed}.',
    'today.weekShort': 'readiness {r}',

    // what your data says
    'insights.section': 'Your own data',
    'insights.title': 'What your data says',
    'insights.entry': '{n} comparisons ready',
    'insights.entryNone': 'Comparisons open here as data accumulates',
    'insights.intro':
        'No scores here; just your own nights compared with each other. Each card '
            'shows two groups of days, each group\'s average and how many days it '
            'comes from. A card only appears with at least four days on each side.',
    'insights.tags': 'Your tags',
    'insights.tagSub': 'Next-morning readiness average',
    'insights.tagWith': 'Mornings after tagged evenings',
    'insights.tagWithout': 'Mornings after untagged evenings',
    'insights.tagResult': 'The gap is {delta} points.',
    'insights.water.title': 'Hydration goal',
    'insights.water.sub': 'Goal {goal} ml · next-morning readiness average',
    'insights.water.a': 'Mornings after days at goal',
    'insights.water.b': 'Mornings after days below goal',
    'insights.auto': 'Found on their own',
    'insights.autoNone':
        'These comparisons need no tags; they come from the data itself. They appear '
            'here after a few weeks of data.',
    'insights.caveat':
        'These are associations, not causes. Nights you went to bed early may differ '
            'in other ways too (weekends, stress, meals). Be careful with gaps that '
            'rest on few days.',
    'insights.erkenYatis.title': 'Going to bed early',
    'insights.erkenYatis.sub': 'Your usual bedtime is {saat} · readiness that morning',
    'insights.erkenYatis.a': 'Nights in bed before {saat}',
    'insights.erkenYatis.b': 'Nights in bed after {saat}',
    'insights.erkenYatis.result': 'Readiness after early nights differs by {delta} points.',
    'insights.yukluGun.title': 'Heavy days',
    'insights.yukluGun.sub': 'Next-morning HRV against your baseline',
    'insights.yukluGun.a': 'Mornings after load above {esik}',
    'insights.yukluGun.b': 'Mornings after load {esik} or below',
    'insights.yukluGun.result':
        'The gap is {delta} z. Negative means HRV drops after heavy days.',
    'insights.adim.title': 'Days you walked a lot',
    'insights.adim.sub': 'Sleep score that night',
    'insights.adim.a': 'Nights after more than {esik} steps',
    'insights.adim.b': 'Nights after {esik} steps or fewer',
    'insights.adim.result': 'The gap is {delta} points.',
    'insights.sekerleme.title': 'Naps',
    'insights.sekerleme.sub': 'Sleep duration that night',
    'insights.sekerleme.a': 'Nights after a nap',
    'insights.sekerleme.b': 'Nights without a nap',
    'insights.sekerleme.result': 'The gap is {delta}.',

    // reminder
    'tags.remind': 'Remind me every evening before bedtime',
    'notif.channel': 'Evening reminder',
    'notif.channelSub': 'Half an hour before bedtime, once a day',
    'notif.title': 'Half an hour to bedtime: {bed}',
    'notif.body': 'How was your evening? Tagging takes one tap.',
    'notif.denied': 'Notification permission was not granted. You can enable it in your phone settings.',
    'notif.enabled': 'I will remind you half an hour before bedtime every evening.',
    'settings.reminder': 'Evening reminder',
    'settings.reminderSub':
        'A single notification half an hour before bedtime; tapping it opens the tag '
            'journal. The time is recalculated each time you open the app.',
    'settings.reminderOff': 'Off',
    'settings.reminderOn': 'On',

    // intraday
    'lvl.calm': 'calm',
    'intraday.section': 'Through the day',
    'intraday.title': 'Through the day',
    'intraday.energy': 'Energy',
    'intraday.energySub': 'Started at {start} this morning · estimate as of {time}',
    'intraday.stress': 'Stress',
    'intraday.stressSub': 'Last hour · {min} of high stress today',
    'intraday.none': 'No daytime heart rate yet today. It fills in as the band syncs.',
    'intraday.energyStart': 'Start',
    'intraday.energyStartSub': 'This morning\'s readiness (sleep score in the first weeks)',
    'intraday.drainLoad': 'Movement and workouts',
    'intraday.drainStress': 'Stress',
    'intraday.drainAwake': 'Hours awake',
    'intraday.energyNote':
        'Energy is an estimate, not a measurement. It starts from readiness and drops '
            'with the same heart rate zones as daily load, with heart rate rising while '
            'still, and with every hour awake. The coefficients are fixed: the heaviest day '
            'takes about 60 points, a fully stressed hour 6, each waking hour 1.5.',
    'intraday.stressHourly': 'Stress by hour',
    'intraday.stressNone': 'Not enough still, awake time today to measure stress.',
    'intraday.highStress': 'Time in high stress',
    'intraday.calmHr': 'Your calm heart rate',
    'intraday.calmHrSub': 'From still, awake moments of recent days; the stress reference',
    'intraday.stressNote':
        'Stress is heart rate rising above your own calm level while you are not moving. '
            'Walking, workouts and sleep are left out. Coffee, heat, illness and excitement '
            'raise heart rate too, so "stress" here means load on the body, not only mental stress.',

    // morning check-in
    'feel.title': 'How do you feel today?',
    'feel.sub': 'One tap. We compare how you feel with your readiness score.',
    'feel.1': 'Exhausted',
    'feel.2': 'Tired',
    'feel.3': 'Okay',
    'feel.4': 'Good',
    'feel.5': 'Great',
    'feel.section': 'How you feel vs. your score',
    'feel.waiting':
        'This needs at least four mornings feeling good (Good, Great) and four feeling '
            'tired (Tired, Exhausted). {n} mornings logged so far.',
    'feel.compareTitle': 'Does the score know you?',
    'feel.compareSub': 'Readiness average that morning',
    'feel.good': 'Mornings you felt good',
    'feel.bad': 'Mornings you felt tired',
    'feel.resultMatch': 'A {delta} point gap: the score clearly tracks how you feel.',
    'feel.resultWeak': 'A {delta} point gap: same direction but weak. It sharpens with more mornings.',
    'feel.resultNone':
        'A {delta} point gap: the score does not track how you feel yet. Things beyond '
            'sleep (stress, illness, alcohol) may move your feeling more than the score.',

    // workouts
    'type.workout': 'Workout',
    'workout.section': 'Workouts',
    'workout.none':
        'No workouts in the last 14 days. They appear here once your band or a sports '
            'app writes them to Health Connect. If you did not grant exercise access, you '
            'can enable it in Health Connect settings.',
    'workout.rowSub': '{date} {time} · {dur} · avg {hr} bpm',
    'workout.load': 'Workout load',
    'workout.share': '{p}% of the day\'s load',
    'workout.hr': 'Average heart rate',
    'workout.hrSub': 'Peak {max} bpm',
    'workout.kcal': 'Calories',
    'workout.distance': 'Distance',
    'workout.nextMorning': 'Next-morning readiness',
    'workout.nextHrv': 'HRV {z} z',
    'workout.note':
        'Workout load uses the same formula as daily load, from minute-level heart rate '
            'during the session, on the same 0-21 scale. Calories and distance come from '
            'the app that recorded the workout.',

    // morning notification
    'notif.morningChannel': 'Morning notification',
    'notif.morningChannelSub': 'Half an hour after your wake time, once a day',
    'notif.morningTitle': 'Good morning, your night is in',
    'notif.morningBody': 'See your readiness and tap how you feel today.',
    'settings.morning': 'Morning notification',
    'settings.morningSub':
        'A single notification half an hour after your wake time. It carries no score: '
            'last night\'s data is not processed yet; the score is computed when you open the app.',
    'workout.type.RUNNING': 'Run',
    'workout.type.RUNNING_TREADMILL': 'Treadmill run',
    'workout.type.WALKING': 'Walk',
    'workout.type.HIKING': 'Hike',
    'workout.type.BIKING': 'Ride',
    'workout.type.BIKING_STATIONARY': 'Indoor ride',
    'workout.type.SWIMMING': 'Swim',
    'workout.type.SWIMMING_POOL': 'Pool swim',
    'workout.type.SWIMMING_OPEN_WATER': 'Open water swim',
    'workout.type.STRENGTH_TRAINING': 'Strength training',
    'workout.type.TRADITIONAL_STRENGTH_TRAINING': 'Weight training',
    'workout.type.FUNCTIONAL_STRENGTH_TRAINING': 'Functional training',
    'workout.type.WEIGHTLIFTING': 'Weightlifting',
    'workout.type.HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
    'workout.type.YOGA': 'Yoga',
    'workout.type.PILATES': 'Pilates',
    'workout.type.ELLIPTICAL': 'Elliptical',
    'workout.type.ROWING': 'Rowing',
    'workout.type.ROWING_MACHINE': 'Rowing machine',
    'workout.type.FOOTBALL_SOCCER': 'Football',
    'workout.type.SOCCER': 'Football',
    'workout.type.BASKETBALL': 'Basketball',
    'workout.type.TENNIS': 'Tennis',
    'workout.type.DANCING': 'Dance',
    'workout.type.OTHER': 'Workout',

    // cycle
    'cycle.title': 'Cycle',
    'cycle.day': 'Day {n}',
    'cycle.phase.regl': 'Period',
    'cycle.phase.folikuler': 'Follicular phase',
    'cycle.phase.luteal': 'Luteal phase: heart rate rises, HRV drops',
    'cycle.note':
        'Cycle day comes from the days you mark in the calendar and from period records in '
            'Health Connect (written by apps like Flo, Clue or Samsung Health). The phase is a rough estimate: ovulation is assumed '
            'about 14 days before the cycle ends. Kerteriz does not do cycle or fertility tracking.',
    'cycle.noAdjust':
        'Readiness is not adjusted for the cycle yet: measuring your own shift needs at '
            'least two cycle starts and eight days in each phase.',
    'cycle.diff':
        'In your data, during the luteal phase resting heart rate shifts by {rhr} bpm and '
            'HRV by {hrv}% on average. This is not a fixed coefficient; it comes from your own past cycles.',
    'cycle.adjustedToday':
        'You are in the luteal phase today; heart rate and HRV were adjusted by that shift, '
            'so the expected rise does not push you toward "rest".',
    'cycle.notLuteal': 'You are not in the luteal phase today; no adjustment applied.',

    // device note
    'device.title': '{src} does not share HRV',
    'device.titleGeneric': 'Your device does not share HRV',
    'device.body':
        'No heart rate variability is reaching Health Connect. Readiness is built from '
            'resting heart rate and sleep; overnight recovery joins once enough data builds up.',
    'device.bodyCardiac':
        'No heart rate variability is reaching Health Connect. Readiness is built from '
            'resting heart rate, sleep and overnight cardiac recovery. The heaviest input is '
            'missing; do not compare the numbers one to one with HRV-capable devices.',
    'data.sources': 'Data sources',
    'data.sourcesNoHrv':
        'Samsung Health and Garmin Connect do not write HRV to Health Connect (Samsung also '
            'skips resting heart rate and respiration). Kerteriz derives resting heart rate '
            'from the overnight series and uses overnight cardiac recovery in place of HRV.',
    'type.menstruation': 'Period records',
    'type.nutrition': 'Nutrition',

    // nutrition comparisons
    'insights.gecYemek.title': 'Late meals',
    'insights.gecYemek.sub': 'Your median from last meal to bed is {h} h · sleep score that night',
    'insights.gecYemek.a': 'Nights you ate less than {h} h before bed',
    'insights.gecYemek.b': 'Nights you ate earlier',
    'insights.gecYemek.result': 'The gap is {delta} points.',
    'insights.kalori.title': 'High-calorie days',
    'insights.kalori.sub': 'Next-morning readiness',
    'insights.kalori.a': 'Mornings after more than {kcal} kcal',
    'insights.kalori.b': 'Mornings after {kcal} kcal or less',
    'insights.kalori.result': 'The gap is {delta} points.',
    'insights.kafein.title': 'Afternoon caffeine',
    'insights.kafein.sub': 'Sleep score that night',
    'insights.kafein.a': 'Days with caffeine after 2 pm',
    'insights.kafein.b': 'Days caffeine ended before 2 pm',
    'insights.kafein.result': 'The gap is {delta} points.',

    // cycle tab and sex
    'tab.cycle': 'Cycle',
    'unit.daysN': '{n} days',
    'cycle.screenTitle': 'Cycle',
    'cycle.phaseNote.regl':
        'Period. Heart rate and HRV usually return to their early-cycle levels these days.',
    'cycle.phaseNote.folikuler':
        'Follicular phase. For most people resting heart rate is lowest and HRV highest now.',
    'cycle.phaseNote.luteal':
        'Luteal phase. Resting heart rate rises and HRV drops; this is an expected change, '
            'not a sign that you are failing to recover.',
    'cycle.thisCycle': 'This cycle',
    'cycle.next': 'Next period',
    'cycle.nextSub': 'Rough estimate from your own average cycle length',
    'cycle.inDays': '~{n} days',
    'cycle.anyDay': 'any day',
    'cycle.length': 'Cycle length',
    'cycle.lengthSub': 'Median of your last {n} cycles; 28 days without data',
    'cycle.adjust': 'Readiness adjusted today',
    'cycle.adjustOff': 'Cycle adjustment is turned off in settings.',
    'cycle.yourShift': 'Your luteal shift',
    'cycle.shiftSub': 'Average of luteal days vs follicular days, from your own data',
    'cycle.rhrChart': 'Resting heart rate, last 8 weeks',
    'cycle.calendar': 'Period days',
    'cycle.calendarNote':
        'Tap days to mark them as period days. Marks stay on your phone only and are not '
            'written to Health Connect. Outlined days come from Health Connect (apps like Flo, '
            'Clue, Samsung Health); change those in that app.',
    'cycle.recent': 'Recent cycles',
    'cycle.current': 'Ongoing',
    'cycle.emptyTitle': 'Cycle not known yet',
    'cycle.emptyBody':
        'Mark your period days in the calendar below, or let me read the records an app like '
            'Flo, Clue or Samsung Health writes to Health Connect.',
    'cycle.grant': 'Allow reading period records',
    'cycle.periodDay': 'period day',
    'cycle.fromHc': 'This day comes from Health Connect; change it in the app that wrote it.',
    'settings.sex': 'Sex',
    'settings.sexFemale': 'Female',
    'settings.sexMale': 'Male',
    'settings.sexNone': 'Not set',
    'settings.sexSub':
        'It enters no score. Choosing female opens the Cycle tab and the cycle settings below. '
            'The choice stays on your phone.',
    'settings.cycle': 'Cycle',
    'settings.cyclePermission': 'Health Connect period records',
    'settings.cyclePermissionOn': 'Being read',
    'settings.cyclePermissionOff': 'No access; tap to allow. Marking in the calendar works without it.',
    'settings.cycleAdjust': 'Adjust readiness for the cycle',
    'settings.cycleNote':
        'When on, heart rate and HRV in the luteal phase are adjusted by the shift measured in '
            'your own past cycles before readiness is computed. Without enough cycles, no adjustment.',

    'cycle.phaseShort.regl': 'Period',
    'cycle.phaseShort.folikuler': 'Follicular',
    'cycle.phaseShort.luteal': 'Luteal',
    'cycle.lengthNone': 'No full cycle yet; {n} days assumed',
    'cycle.adjustWaiting': 'Not yet: not enough cycle data to measure your own shift',
    'cycle.progressStarts': 'Cycle starts',
    'cycle.progressLuteal': 'Measured days in the luteal phase',
    'cycle.progressFollicular': 'Measured days in the follicular phase',
    'cycle.progressDone': 'done',
    'cycle.progressNote':
        'Once all three fill up, your luteal shift in heart rate and HRV is measured from '
            'your own data and readiness is adjusted for it. Marking period days in the '
            'calendar counts cycle starts.',

    // tag journal
    'tags.title': 'This evening',
    'tags.sub': 'One tap. Compared with the next morning\'s readiness.',
    'tags.none': 'None',
    'tag.alkol': 'Alcohol',
    'tag.kafein': 'Late caffeine',
    'tag.gecYemek': 'Late meal',
    'tag.stres': 'High stress',
    'tag.gecAntrenman': 'Late workout',
    'tags.waiting':
        'Showing a tag\'s effect needs at least four evenings with it and four '
            'without. {n} evenings logged so far. If nothing applies, tap "None": '
            'evenings left unlogged are not counted.',

    // weekly summary
    'today.week': 'Weekly summary',
    'today.weekReadiness': 'Average readiness',
    'today.weekNights': 'Last 7 days, {n} nights',
    'today.weekVsPrev': 'Previous week {prev} · change {delta}',
    'today.weekSleep': 'Average sleep',
    'today.weekSleepScore': 'Sleep score average {score}',
    'today.weekSleepVsPrev': 'Sleep score {score} · {delta} vs previous week',
    'today.weekBest': 'Best night',
    'today.weekBestSub': '{date} · {sleep} asleep',
    'today.weekDebt': 'Debt change',
    'today.weekDebtSub': 'A week ago {ago}',
    'today.weekDebtUp': 'Rising',
    'today.weekDebtDown': 'Falling',
    'today.weekDebtFlat': 'Steady',

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
    'load.ratioWaiting':
        'The 28-day chronic window is not full yet; the ratio would read too high',
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
    'heart.noValue': 'No records arrive from this device',
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
    'unit.year': 'years',
    'unit.step': 'steps',
    'unit.kcal': 'kcal',
    'unit.km': 'km',
    'settings.personal': 'Personal',
    'settings.age': 'Age',
    'settings.ageSub': 'Estimated maximum heart rate: {hr} bpm',
    'settings.ageNote':
        'Heart rate zones and the daily load figure depend on age '
        '(208 - 0.7 x age). Changing it reprocesses your data.',
    'settings.wake': 'Wake time',
    'settings.wakeSub': 'The suggested bedtime counts back from this',
    'settings.goals': 'Daily goals',
    'settings.waterGoal': 'Water goal',
    'settings.waterGoalSub': 'The meter on Today and the water widget',
    'settings.waterServing': 'Water serving',
    'settings.waterServingSub': 'Amount added on each widget tap',
    'settings.stepGoal': 'Steps',
    'settings.ringSub': 'Ring on the home screen summary widget',
    'settings.calorieGoal': 'Calories (total)',
    'settings.calorieGoalSub': 'Daily total including basal',
    'settings.activeCalorieGoal': 'Calories (active)',
    'settings.activeCalorieGoalSub':
        'Used when the device only writes active calories',
    'settings.distanceGoal': 'Distance',
    'settings.goalsNote':
        'Goals do not feed the scores; they only set the meters and rings. '
        'Changes reach the widgets on their next refresh.',
    'settings.title': 'Settings',
    'settings.about': 'About',
    'settings.dataTabSub':
        'To see what actually arrives from Health Connect, open the Data tab: '
        'it lists how many records each metric returned and which ones are empty.',
    'settings.appearance': 'Appearance',
    'settings.themeSystem': 'System',
    'settings.themeLight': 'Light',
    'settings.themeDark': 'Dark',
    'settings.themeSub':
        'On system, the phone dark mode is followed. The choice is saved.',
    'data.summary': 'Summary',
    'data.timedOut':
        'These types did not answer in time and the read was cut short: {list}. '
            'Health Connect sometimes stalls on a single type; try reloading.',
    'data.version': 'App version',
    'data.versionSub': 'The build running on this phone',
    'data.requested': 'Requested window',
    'data.requestedSub': 'How many days back the app asks for',
    'data.lastFullRead': 'Last full read',
    'data.lastFullReadSub':
        'The counts below come from that read. On launch only the last few '
        'days are refreshed; the rest is loaded from the cache.',
    'data.fullRead': 'Read all 90 days again',
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
    'data.capIllnessNightHr':
        'No respiration or temperature; a simpler version based on overnight heart rate runs',
    'data.capReadinessNoHrv':
        'No HRV arriving. 40% of the score is missing; built from heart rate, sleep and overnight recovery',
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
            'what came from the phone\'s own Health Connect store. The only thing the '
            'app writes is the water you log yourself, and that goes back into the '
            'phone\'s own store.',
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
    'type.water': 'Water',

    'legal.disclaimer':
        'This app does not diagnose and does not give medical advice. It shows your own '
            'data against your own baseline. Talk to a clinician about health decisions.',
  };
}
