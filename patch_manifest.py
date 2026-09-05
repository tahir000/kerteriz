#!/usr/bin/env python3
"""Flutter'in urettigi AndroidManifest.xml'i YERINDE yamalar.

Uzerine yazmaz: Flutter'in kendi urettigi dosya, o surumun bekledigi
embedding yapilandirmasini zaten dogru tasiyor. Biz sadece Health Connect
icin gereken izinleri, queries blogunu ve izin gerekcesi ekranlarini
ekliyoruz. Ayni dosyaya ikinci kez calistirmak zararsizdir.
"""
import re
import sys

MARK = "<!-- kerteriz:health-connect -->"

PERMISSIONS = """    """ + MARK + """
    <!-- Health Connect: yalnizca READ, hicbir WRITE yok -->
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
    <uses-permission android:name="android.permission.health.READ_RESTING_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
    <uses-permission android:name="android.permission.health.READ_RESPIRATORY_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SKIN_TEMPERATURE"/>
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_WEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_VO2_MAX"/>
    <!-- 30 gunden eski kayitlar icin sart; taban cizgiler buna bagli -->
    <uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>

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


def main(path):
    src = open(path, encoding="utf-8").read()

    if MARK in src:
        print("   manifest zaten yamali, atlaniyor")
        return 0

    if "<application" not in src:
        print("   HATA: <application> bulunamadi, manifest beklenmedik bicimde", file=sys.stderr)
        return 1

    # 1) izinler -> <application> etiketinden hemen once
    src = src.replace("<application", PERMISSIONS + "<application", 1)

    # 1b) queries: zaten bir blok varsa icine ekle, yoksa yeni blok ac.
    # Birden fazla <queries> yazmaktansa mevcut olani genisletmek daha guvenli.
    if "<queries>" in src:
        src = src.replace("<queries>", "<queries>" + QUERIES_BODY, 1)
    else:
        src = src.replace("<application", QUERIES_BLOCK + "<application", 1)

    # 2) izin gerekcesi intent-filter -> MainActivity activity blogunun sonuna
    m = re.search(r'(<activity\b[^>]*android:name="\.MainActivity".*?)(</activity>)',
                  src, re.S)
    if m:
        src = src[:m.end(1)] + RATIONALE + "        " + src[m.end(1):]
    else:
        print("   UYARI: MainActivity bulunamadi, gerekce intent-filter eklenmedi")

    # 3) activity-alias -> </application> etiketinden hemen once
    src = src.replace("</application>", ALIAS + "\n    </application>", 1)

    # 4) uygulama adi
    src = re.sub(r'android:label="[^"]*"', 'android:label="Kerteriz"', src, count=1)

    open(path, "w", encoding="utf-8").write(src)
    print("   manifest yamalandi")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
