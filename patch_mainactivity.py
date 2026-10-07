#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Flutter'ın ürettiği MainActivity'yi FlutterFragmentActivity'ye çevirir.

health paketi Android 14'te activity result kaydı için FlutterActivity yerine
FlutterFragmentActivity ister. Dosyayı üzerine yazmak yerine yamalıyoruz;
böylece Flutter'ın seçtiği paket adı ne olursa olsun doğru kalıyor.
"""
import glob
import re
import sys

# Uygulama arka plana geçerken widget'ları tazeler: özet dosyası az önce
# yazıldı, widget'lar 30 dakikalık periyodu beklemesin.
GOVDE = """class MainActivity : FlutterFragmentActivity() {
    override fun onStop() {
        super.onStop()
        WidgetYenileyici.hepsi(this)
    }
}
"""


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
        onceki = src
        src = src.replace(
            "import io.flutter.embedding.android.FlutterActivity\n",
            "import io.flutter.embedding.android.FlutterFragmentActivity\n")
        src = src.replace(": FlutterActivity()", ": FlutterFragmentActivity()")
        src = src.replace(":FlutterActivity()", ": FlutterFragmentActivity()")
        # Gövdesiz (Flutter'ın ürettiği) sınıfa widget kancasını ekle.
        if "WidgetYenileyici" not in src:
            src, n = re.subn(
                r"class MainActivity\s*:\s*FlutterFragmentActivity\(\)\s*(\{\s*\})?\s*$",
                GOVDE, src, flags=re.M)
            if n == 0:
                print("   UYARI: MainActivity'nin gövdesi var, widget kancası eklenmedi")
        if src == onceki:
            print("   MainActivity zaten güncel")
            continue
        open(path, "w", encoding="utf-8").write(src)
        print("   MainActivity yamalandı")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
