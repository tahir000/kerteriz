#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Flutter'ın ürettiği MainActivity'yi FlutterFragmentActivity'ye çevirir.

health paketi Android 14'te activity result kaydı için FlutterActivity yerine
FlutterFragmentActivity ister. Dosyayı üzerine yazmak yerine yamalıyoruz;
böylece Flutter'ın seçtiği paket adı ne olursa olsun doğru kalıyor.
"""
import glob
import sys


def main(project):
    hits = (glob.glob(project + "/android/app/src/main/kotlin/**/MainActivity.kt",
                      recursive=True)
            + glob.glob(project + "/android/app/src/main/java/**/MainActivity.kt",
                        recursive=True))
    if not hits:
        print("   UYARI: MainActivity.kt bulunamadı", file=sys.stderr)
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
        print("   MainActivity FlutterFragmentActivity'ye çevrildi")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
