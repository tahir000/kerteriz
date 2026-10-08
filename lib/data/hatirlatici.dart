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
  static const int _sabahId = 2;
  static const String etiketYuku = 'etiket';
  static const String sabahYuku = 'sabah';

  /// Sabah bildirimi kalkış saatinden kaç dakika sonra gelsin. Bileklik
  /// gecenin verisini birkaç dakikada eşitliyor; yarım saat yeterli pay.
  static const int sabahSonraDk = 30;

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

  static Future<void> _kur({
    required int id,
    required int dakika,
    required String kanal,
    required String kanalAdi,
    required String kanalAciklama,
    required String baslik,
    required String govde,
    required String yuk,
  }) async {
    final an = sonraki(DateTime.now(), dakika);
    await _eklenti.zonedSchedule(
      id: id,
      // Yerel saat dilimini bilmeden doğru anı vermek için mutlak an
      // UTC olarak veriliyor. Günlük tekrar da UTC saatine bağlı; yaz saati
      // geçişinde bir saat kayabilir, ama uygulama her açılışta yeniden
      // kurduğu için kayma bir sonraki açılışta düzeliyor.
      scheduledDate: tz.TZDateTime.from(an.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kanal,
          kanalAdi,
          channelDescription: kanalAciklama,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: baslik,
      body: govde,
      payload: yuk,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Tercihlere göre bildirimleri kurar ya da kaldırır.
  static Future<void> planla(List<DayRecord> days,
      {List<DayRecord>? allDays}) async {
    if (days.isEmpty) return;
    await baslat();
    if (!_hazir) return;
    try {
      await _eklenti.cancel(id: _id);
      await _eklenti.cancel(id: _sabahId);
      final s = S.forCode(DayRecord.locale);

      if (Ayarlar.hatirlatma) {
        final plan = Gunluk.planFor(days,
            allDays: allDays, wakeMinute: Ayarlar.kalkisDk);
        await _kur(
          id: _id,
          dakika: plan.bedMinute - onceDk,
          kanal: 'aksam',
          kanalAdi: s.t('notif.channel'),
          kanalAciklama: s.t('notif.channelSub'),
          baslik: s.t2('notif.title', {'bed': saatDakika(plan.bedMinute)}),
          govde: s.t('notif.body'),
          yuk: etiketYuku,
        );
      }

      // Sabah bildirimi sayı içermiyor: o saatte bu geceki veri henüz
      // uygulamada işlenmedi, skoru ancak uygulama açılınca hesaplıyor.
      // Bildirim bu yüzden davet: aç, hazırlığını gör, nasıl hissettiğini işaretle.
      if (Ayarlar.sabahBildirimi) {
        await _kur(
          id: _sabahId,
          dakika: Ayarlar.kalkisDk + sabahSonraDk,
          kanal: 'sabah',
          kanalAdi: s.t('notif.morningChannel'),
          kanalAciklama: s.t('notif.morningChannelSub'),
          baslik: s.t('notif.morningTitle'),
          govde: s.t('notif.morningBody'),
          yuk: sabahYuku,
        );
      }
    } catch (_) {
      // Zamanlanamadıysa uygulama yine çalışır; ayarlar ekranı tercihi tutar.
    }
  }
}
