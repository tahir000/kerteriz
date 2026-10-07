import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n.dart';
import '../metrics/insights.dart';
import 'ayarlar.dart';
import 'day_record.dart';

/// Akşam hatırlatması: yatma saatinden yarım saat önce tek bildirim.
///
/// İki iş görüyor: yatma saatini hatırlatıyor ve etiket günlüğünü açtırıyor.
/// Etiket karşılaştırmaları ancak akşamlar düzenli işaretlenirse dolar;
/// hatırlatma olmadan çoğu akşam unutuluyor.
///
/// Sunucu yok, internet yok: bildirim telefonda zamanlanıyor. Yatma saati
/// her gün değiştiği için uygulama her açıldığında yeniden kuruluyor; kurulan
/// bildirim her gün aynı saatte tekrarlıyor, yani uygulama birkaç gün
/// açılmasa da hatırlatma susmuyor, yalnızca son hesaplanan saatte kalıyor.
class Hatirlatici {
  static const int _id = 1;
  static const String etiketYuku = 'etiket';

  /// Önceden kaç dakika hatırlatılsın.
  static const int onceDk = 30;

  static final _eklenti = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  /// Bildirime dokunulunca dolar; [Shell] dinliyor ve etiket sayfasını açıyor.
  static final ValueNotifier<String?> acilis = ValueNotifier<String?>(null);

  static Future<void> baslat() async {
    if (_hazir) return;
    try {
      tzdata.initializeTimeZones();
      await _eklenti.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) => acilis.value = r.payload,
      );
      // Uygulama kapalıyken bildirimden açıldıysa.
      final ilk = await _eklenti.getNotificationAppLaunchDetails();
      if (ilk?.didNotificationLaunchApp ?? false) {
        acilis.value = ilk!.notificationResponse?.payload;
      }
      _hazir = true;
    } catch (_) {
      // Bildirim altyapısı yoksa (test, eski cihaz) uygulama yine çalışır.
    }
  }

  /// Android 13+ bildirim izni. Reddedilirse false.
  static Future<bool> izinIste() async {
    await baslat();
    try {
      final android = _eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [simdi]'den sonraki ilk [dakika] (gece yarısından) anı.
  static DateTime sonraki(DateTime simdi, int dakika) {
    final m = ((dakika % 1440) + 1440) % 1440;
    var t = DateTime(simdi.year, simdi.month, simdi.day, m ~/ 60, m % 60);
    if (!t.isAfter(simdi)) t = DateTime(t.year, t.month, t.day + 1, m ~/ 60, m % 60);
    return t;
  }

  /// Tercihe göre bildirimi kurar ya da kaldırır.
  static Future<void> planla(List<DayRecord> days,
      {List<DayRecord>? allDays}) async {
    if (days.isEmpty) return;
    await baslat();
    if (!_hazir) return;
    try {
      await _eklenti.cancel(id: _id);
      if (!Ayarlar.hatirlatma) return;

      final plan = Gunluk.planFor(days,
          allDays: allDays, wakeMinute: Ayarlar.kalkisDk);
      final s = S.forCode(DayRecord.locale);
      final an = sonraki(DateTime.now(), plan.bedMinute - onceDk);
      await _eklenti.zonedSchedule(
        id: _id,
        // Yerel saat dilimini bilmeden doğru anı vermek için mutlak an
        // UTC olarak veriliyor. Günlük tekrar da UTC saatine bağlı; yaz saati
        // geçişinde bir saat kayabilir, ama uygulama her açılışta yeniden
        // kurduğu için kayma bir sonraki açılışta düzeliyor.
        scheduledDate: tz.TZDateTime.from(an.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'aksam',
            s.t('notif.channel'),
            channelDescription: s.t('notif.channelSub'),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: s.t2('notif.title', {'bed': saatDakika(plan.bedMinute)}),
        body: s.t('notif.body'),
        payload: etiketYuku,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Zamanlanamadıysa uygulama yine çalışır; ayarlar ekranı tercihi tutar.
    }
  }
}
