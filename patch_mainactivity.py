#!/usr/bin/env python3
"""Flutter'in urettigi MainActivity'yi FlutterFragmentActivity'ye cevirir.

health paketi Android 14'te activity result kaydi icin FlutterActivity yerine
FlutterFragmentActivity ister. Dosyayi uzerine yazmak yerine yamaliyoruz;
boylece Flutter'in sectigi paket adi ne olursa olsun dogru kaliyor.
"""
import glob
import sys


def main(project):
    hits = (glob.glob(project + "/android/app/src/main/kotlin/**/MainActivity.kt",
                      recursive=True)
            + glob.glob(project + "/android/app/src/main/java/**/MainActivity.kt",
                        recursive=True))
    if not hits:
        print("   UYARI: MainActivity.kt bulunamadi", file=sys.stderr)
        return 0

    for path in hits:
        src = open(path, encoding="utf-8").read()
        if "FlutterFragmentActivity" in src:
            print("   MainActivity zaten FlutterFragmentActivity")
            continue
        src = src.replace(
            "import io.flutter.embedding.android.FlutterActivity",
            "import io.flutter.embedding.android.FlutterFragmentActivity")
        src = src.replace(": FlutterActivity()", ": FlutterFragmentActivity()")
        src = src.replace(":FlutterActivity()", ": FlutterFragmentActivity()")
        open(path, "w", encoding="utf-8").write(src)
        print("   MainActivity FlutterFragmentActivity'ye cevrildi")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
