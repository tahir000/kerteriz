#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Flutter'ın ürettiği AndroidManifest.xml'i YERİNDE yamalar.

Üzerine yazmaz: Flutter'ın kendi ürettiği dosya, o sürümün beklediği
embedding yapılandırmasını zaten doğru taşıyor. Biz sadece Health Connect
için gereken izinleri, queries bloğunu, izin gerekçesi ekranlarını ve
su widget'ının alıcısını ekliyoruz. Aynı dosyaya ikinci kez çalıştırmak zararsızdır.
"""
import re
import sys

MARK = "<!-- kerteriz:health-connect -->"

PERMISSIONS = """    """ + MARK + """
    <!-- Health Connect: su alımı dışında hepsi salt okunur.
         Tek yazma izni WRITE_HYDRATION; ana ekran widget'ı için. -->
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
    <uses-permission android:name="android.permission.health.READ_RESTING_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
    <uses-permission android:name="android.permission.health.READ_RESPIRATORY_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SKIN_TEMPERATURE"/>
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <!-- Antrenmanlar: Yük sekmesindeki liste ve antrenman yükü (isteğe bağlı) -->
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <!-- Döngü: regl kayıtları, hazırlığı döngü evresine göre düzeltmek için (isteğe bağlı) -->
    <uses-permission android:name="android.permission.health.READ_MENSTRUATION"/>
    <!-- Beslenme: başka uygulamaların yazdığı öğünler, yalnızca okuma (isteğe bağlı) -->
    <uses-permission android:name="android.permission.health.READ_NUTRITION"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <!-- Su widget'ı: okuma VE yazma. Uygulamadaki tek yazma izni budur. -->
    <uses-permission android:name="android.permission.health.READ_HYDRATION"/>
    <uses-permission android:name="android.permission.health.WRITE_HYDRATION"/>
    <!-- 30 gunden eski kayitlar icin sart; taban cizgiler buna bagli -->
    <uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
    <!-- Akşam hatırlatması: telefon yeniden başlayınca bildirim yeniden kurulsun.
         POST_NOTIFICATIONS izni bildirim eklentisinin kendi manifestinde. -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

"""

QUERIES_BODY = """
        <package android:name="com.google.android.apps.healthdata" />
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent>
"""

QUERIES_BLOCK = """    <queries>""" + QUERIES_BODY + """    </queries>

"""

RATIONALE = """
            <!-- Android 13 ve oncesi: izin gerekcesi ekrani -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
"""

WIDGET_SU = """
        <!-- Ana ekran su widget'i -->
        <receiver
            android:name=".SuWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="com.kerteriz.kerteriz.SU_EKLE" />
                <action android:name="com.kerteriz.kerteriz.SU_GERI_AL" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/su_widget_info" />
        </receiver>
"""

WIDGET_OZET = """
        <!-- Ana ekran ozet widget'i (adim / kalori / mesafe + skorlar) -->
        <receiver
            android:name=".OzetWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="com.kerteriz.kerteriz.OZET_YENILE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/ozet_widget_info" />
        </receiver>
"""

WIDGET_BUGUN = """
        <!-- Ana ekran Bugun widget'i (hazirlik + dort halka + su) -->
        <receiver
            android:name=".BugunWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="com.kerteriz.kerteriz.BUGUN_SU_EKLE" />
                <action android:name="com.kerteriz.kerteriz.BUGUN_YENILE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/bugun_widget_info" />
        </receiver>
"""

BILDIRIM = """
        <!-- Akşam hatırlatması (flutter_local_notifications) -->
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

ALIAS = """
        <!-- Android 14+: izin gerekcesi ekrani -->
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>
"""


IZIN_SATIRLARI = [r for r in PERMISSIONS.splitlines() if "uses-permission" in r]

# Eskiden istenip artık kullanılmayan izinler. Play sağlık izinlerini tek tek
# inceliyor ve kullanılmayan izin reddedilme sebebi; daha önce yamalanmış
# projelerden de siliniyorlar.
ESKI_IZINLER = [
    "android.permission.health.READ_WEIGHT",
    "android.permission.health.READ_VO2_MAX",
]


def _izin_adi(satir):
    m = re.search(r'android:name="([^"]+)"', satir)
    return m.group(1) if m else None


def main(path):
    """Her parçanın kendi koruması var: daha önce yamalanmış bir projeyi de
    günceller. Tek bir "zaten yamalı" kontrolü kullanmıyoruz, çünkü sonradan
    eklenen bir izin ya da widget o projeye hiç girmiyordu."""
    src = open(path, encoding="utf-8").read()

    if "<application" not in src:
        print("   HATA: <application> bulunamadı, manifest beklenmedik biçimde",
              file=sys.stderr)
        return 1

    onceki = src

    # 1) izinler -> <application> etiketinden hemen önce
    if MARK not in src:
        src = src.replace("<application", PERMISSIONS + "<application", 1)
    else:
        # Zaten yamalı: yalnızca sonradan eklenen izinleri tamamla.
        eksik = [r for r in IZIN_SATIRLARI
                 if '"%s"' % _izin_adi(r) not in src]
        if eksik:
            src = src.replace(MARK, MARK + "\n" + "\n".join(eksik), 1)
            print("   eklenen izin:", ", ".join(_izin_adi(r) for r in eksik))

    # 1a) artık kullanılmayan izinleri sil
    for ad in ESKI_IZINLER:
        yeni = re.sub(r'[ \t]*<uses-permission android:name="%s"\s*/>\n?' % re.escape(ad), "", src)
        if yeni != src:
            print("   kaldırılan izin:", ad)
            src = yeni

    # 1b) queries: zaten bir blok varsa içine ekle, yoksa yeni blok aç.
    # Birden fazla <queries> yazmaktansa mevcut olanı genişletmek daha güvenli.
    if "com.google.android.apps.healthdata" not in src:
        if "<queries>" in src:
            src = src.replace("<queries>", "<queries>" + QUERIES_BODY, 1)
        else:
            src = src.replace("<application", QUERIES_BLOCK + "<application", 1)

    # 2) izin gerekçesi intent-filter -> MainActivity activity bloğunun sonuna
    if "Android 13 ve oncesi" not in src:
        m = re.search(
            r'(<activity\b[^>]*android:name="\.MainActivity".*?)(</activity>)',
            src, re.S)
        if m:
            src = src[:m.end(1)] + RATIONALE + "        " + src[m.end(1):]
        else:
            print("   UYARI: MainActivity bulunamadı, gerekçe intent-filter eklenmedi")

    # 3) activity-alias ve widget alıcıları -> </application> etiketinden önce
    eklenecek = ""
    if "ViewPermissionUsageActivity" not in src:
        eklenecek += ALIAS
    if ".SuWidgetProvider" not in src:
        eklenecek += WIDGET_SU
    if ".OzetWidgetProvider" not in src:
        eklenecek += WIDGET_OZET
    if ".BugunWidgetProvider" not in src:
        eklenecek += WIDGET_BUGUN
    if "ScheduledNotificationReceiver" not in src:
        eklenecek += BILDIRIM
    if eklenecek:
        src = src.replace("</application>", eklenecek + "\n    </application>", 1)

    # 4) uygulama adı
    if 'android:label="Kerteriz"' not in src:
        src = re.sub(r'android:label="[^"]*"', 'android:label="Kerteriz"', src, count=1)

    if src == onceki:
        print("   manifest zaten güncel")
        return 0

    open(path, "w", encoding="utf-8").write(src)
    print("   manifest yamalandı")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
