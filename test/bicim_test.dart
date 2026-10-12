import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/theme.dart';

void main() {
  test('süre: Türkçe boşluklu, saniyeyle karışmıyor', () {
    expect(fmtDur(213), '3\u00A0sa 33\u00A0dk');
    expect(fmtDur(185), '3\u00A0sa 5\u00A0dk');
    expect(fmtDur(120), '2\u00A0sa');
    expect(fmtDur(45), '45\u00A0dk');
  });

  test('süre: İngilizce bitişik', () {
    expect(fmtDur(213, h: 'h', m: 'm'), '3h 33m');
    expect(fmtDur(185, h: 'h', m: 'm'), '3h 05m');
  });

  test('dinlenme nabzı normalinden yüksekse "altında" değil "yüksek"', () {
    expect(Levels.rhrKey(0.2), 'lvl.normal');
    expect(Levels.rhrKey(1.0), 'lvl.slightlyHigh');
    expect(Levels.rhrKey(2.0), 'lvl.high');
    // Düşük nabız iyi: normal sayılıyor.
    expect(Levels.rhrKey(-2.0), 'lvl.normal');
  });

  test('sapma cümlesi işarete göre', () {
    expect(Levels.sapmaKey(0.3), 'dev.normal');
    expect(Levels.sapmaKey(-1.0), 'dev.slightlyLow');
    expect(Levels.sapmaKey(-2.0), 'dev.low');
    expect(Levels.sapmaKey(1.0), 'dev.slightlyHigh');
    expect(Levels.sapmaKey(2.0), 'dev.high');
  });
}
