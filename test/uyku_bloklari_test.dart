import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/day_record.dart';
import 'package:kerteriz/data/uyku_bloklari.dart';

/// Gerçek bir gecenin biçimi (17 Eylül): akşam 17:34'te bir saatlik
/// kestirme, gece 02:11-10:47 asıl uyku, öğlen 12:31'de bir saat daha.
void main() {
  SleepSegment s(String st, int g, int h, int m, int dk) {
    final a = DateTime(2026, 9, g, h, m);
    return SleepSegment(st, a, a.add(Duration(minutes: dk)));
  }

  test('şekerlemeler gece uykusundan ayrılır', () {
    final rec = DayRecord(DateTime(2026, 9, 17));
    rec.segments = [
      s('light', 16, 17, 34, 64),
      s('light', 17, 2, 11, 200),
      s('deep', 17, 5, 31, 90),
      s('awake', 17, 7, 1, 20),
      s('rem', 17, 7, 21, 120),
      s('light', 17, 9, 21, 86),
      s('light', 17, 12, 31, 74),
    ];
    uykuyuTopla(rec);
    expect(rec.bedStart, DateTime(2026, 9, 17, 2, 11));
    expect(rec.wakeEnd, DateTime(2026, 9, 17, 10, 47));
    expect(rec.timeInBed, 516);
    expect(rec.asleep, 200 + 90 + 120 + 86);
    expect(rec.awakenings, 1);
    expect(rec.napMinutes, 64 + 74);
    expect(rec.segments.length, 5);
  });

  test('60 dakikaya kadar uyanıklık aynı gece sayılır', () {
    final rec = DayRecord(DateTime(2026, 9, 17));
    rec.segments = [
      s('light', 17, 0, 0, 180),
      s('light', 17, 3, 50, 200), // 50 dk boşluk
    ];
    uykuyuTopla(rec);
    expect(rec.napMinutes, 0);
    expect(rec.timeInBed, 3 * 60 + 50 + 200);
  });

  test('en çok uykulu blok gece sayılır, ilk blok değil', () {
    final rec = DayRecord(DateTime(2026, 9, 16));
    rec.segments = [
      s('light', 16, 3, 12, 111),
      s('light', 16, 14, 0, 202),
    ];
    uykuyuTopla(rec);
    expect(rec.bedStart, DateTime(2026, 9, 16, 14, 0));
    expect(rec.napMinutes, 111);
  });
}
