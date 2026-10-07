import 'day_record.dart';

/// Aynı "uyku gününe" düşen evre kayıtlarını gece uykusu ve şekerlemeler
/// olarak ayırıp kaydın uyku alanlarını doldurur.
///
/// 0.10.0'a kadar bütün parçalar tek oturum sayılıyordu: yatış ilk parçanın
/// başı, kalkış son parçanın sonuydu. Öğleden sonra 14:00'te yarım saat
/// kestiren birinin gecesi 20 saat "yatakta" görünüyor, verimi %50'ye düşüp
/// uyku skoru haksız yere kırılıyordu (gerçek veride 32 gecenin 6'sı).
///
/// Şimdi: aralarında [ayrimDk] dakikadan uzun boşluk olan parçalar ayrı
/// bloktur. En çok uyku içeren blok gece uykusudur; yatış, kalkış, verim,
/// evreler, uyanmalar ve zamanlama yalnızca ondan hesaplanır. Öteki
/// bloklardaki uyku [DayRecord.napMinutes] olarak tutulur ve yalnızca uyku
/// borcuna sayılır: şekerleme borcu öder, ama gecenin kalitesini anlatmaz.
const int ayrimDk = 60;

void uykuyuTopla(DayRecord rec) {
  if (rec.segments.isEmpty) return;
  final seg = [...rec.segments]..sort((a, b) => a.start.compareTo(b.start));

  final bloklar = <List<SleepSegment>>[];
  var cur = <SleepSegment>[seg.first];
  var sonBitis = seg.first.end;
  for (final s in seg.skip(1)) {
    if (s.start.difference(sonBitis).inMinutes > ayrimDk) {
      bloklar.add(cur);
      cur = <SleepSegment>[];
    }
    cur.add(s);
    if (s.end.isAfter(sonBitis)) sonBitis = s.end;
  }
  bloklar.add(cur);

  int uyku(List<SleepSegment> b) =>
      b.where((s) => s.stage != 'awake').fold(0, (a, s) => a + s.minutes);

  var ana = bloklar.first;
  for (final b in bloklar) {
    if (uyku(b) > uyku(ana)) ana = b;
  }

  rec.segments = ana;
  rec.napMinutes = 0;
  for (final b in bloklar) {
    if (!identical(b, ana)) rec.napMinutes += uyku(b);
  }

  rec.bedStart = ana.first.start;
  var bitis = ana.first.end;
  for (final s in ana) {
    if (s.end.isAfter(bitis)) bitis = s.end;
  }
  rec.wakeEnd = bitis;
  rec.timeInBed = bitis.difference(rec.bedStart!).inMinutes;
  rec.deep = rec.rem = rec.light = rec.awakeMinutes = rec.awakenings = 0;
  for (final s in ana) {
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
  if (rec.timeInBed < rec.asleep) {
    rec.timeInBed = rec.asleep + rec.awakeMinutes;
  }
}
