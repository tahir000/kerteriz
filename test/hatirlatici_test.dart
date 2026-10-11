import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/hatirlatici.dart';

void main() {
  group('suSaatleri', () {
    test('saat başı: kalkıştan bir saat sonra başlar, yatıştan bir saat önce biter', () {
      // 07:00 kalkış, 23:00 yatış → 08:00 .. 22:00
      final s = Hatirlatici.suSaatleri(7 * 60, 23 * 60, 60);
      expect(s.first, 8 * 60);
      expect(s.last, 22 * 60);
      expect(s.length, 15);
    });

    test('yatış gece yarısını geçiyor', () {
      // 08:00 kalkış, 00:30 yatış → son hatırlatma 23:30'dan sonra değil
      final s = Hatirlatici.suSaatleri(8 * 60, 30, 90);
      expect(s.first, 9 * 60 + 30);
      expect(s.last, lessThanOrEqualTo(23 * 60 + 30));
      expect(s.every((m) => m >= 0 && m < 1440), isTrue);
    });

    test('kısa aralık üst sınırı aşmaz', () {
      final s = Hatirlatici.suSaatleri(6 * 60, 23 * 60, 15);
      expect(s.length, lessThanOrEqualTo(Hatirlatici.suEnCok));
      expect(s.first, 6 * 60 + 15);
    });

    test('geçersiz aralık boş liste verir', () {
      expect(Hatirlatici.suSaatleri(420, 1380, 0), isEmpty);
    });
  });
}
