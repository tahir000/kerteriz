#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Native su widget'ını üretilen Flutter projesine yerleştirir.

Yaptıkları:
  1. native/kotlin/*.kt  -> android/app/src/main/kotlin/<paket yolu>/
  2. native/res/**       -> android/app/src/main/res/  (birleştirerek)
  3. build.gradle.kts'ye Health Connect ve coroutines bağımlılıklarını ekler
  4. Kotlin dosyalarının paket adını MainActivity.kt'ninkiyle eşitler
  5. lib/config.dart'taki su hedefi ve porsiyonu widget'a yazar

Idempotent: aynı projede tekrar çalıştırmak zararsızdır.
"""
import glob
import os
import re
import shutil
import sys

DEPS = [
    ('androidx.health.connect:connect-client', '1.1.0'),
    ('org.jetbrains.kotlinx:kotlinx-coroutines-android', '1.10.2'),
]


def kotlin_hedefi(proje):
    """MainActivity.kt nerede ise Kotlin kaynakları oraya gider."""
    adaylar = (
        glob.glob(proje + '/android/app/src/main/kotlin/**/MainActivity.kt',
                  recursive=True)
        + glob.glob(proje + '/android/app/src/main/java/**/MainActivity.kt',
                    recursive=True))
    if adaylar:
        return os.path.dirname(adaylar[0])
    return None


def paket_adi(hedef_kotlin):
    """MainActivity.kt'nin paket adını okur; Kotlin dosyaları ona uydurulur."""
    yol = os.path.join(hedef_kotlin, 'MainActivity.kt')
    m = re.search(r'^\s*package\s+([\w.]+)', open(yol, encoding='utf-8').read(), re.M)
    return m.group(1) if m else None


def su_sabitleri(here):
    """lib/config.dart widget varsayilanlarinin kaynagi.

    0.8.0'dan beri gercek hedefler kullanicinin ayarlarindan geliyor ve
    Kotlin tarafina kerteriz_ozet.json ile tasiniyor. Buradaki enjeksiyon
    yalnizca yedegi ayarliyor: uygulama hic acilmadan widget eklenirse
    widget bu sayilara duser.
    Dönen sözlüğün anahtarları Kotlin'deki sabit adlarıdır."""
    src = open(os.path.join(here, 'lib/config.dart'), encoding='utf-8').read()

    def oku(ad, varsayilan):
        m = re.search(r'int\s+%s\s*=\s*(\d+)' % ad, src)
        return int(m.group(1)) if m else varsayilan

    return {
        'VARSAYILAN_PORSIYON': oku('waterServingMl', 250),
        'VARSAYILAN_HEDEF': oku('dailyWaterGoalMl', 2500),
        'HEDEF_ADIM': oku('dailyStepGoal', 10000),
        'HEDEF_KALORI': oku('dailyCalorieGoal', 2400),
        'HEDEF_KALORI_AKTIF': oku('dailyActiveCalorieGoal', 600),
        'HEDEF_MESAFE_ONDA_KM': oku('dailyDistanceTenthKm', 70),
    }


def kotlini_uyarla(yol, paket, sabitler):
    """Kopyalanan Kotlin dosyasını paket adına ve config.dart değerlerine göre
    yeniden yazar. Her çalıştırmada aynı sonucu üretir."""
    src = open(yol, encoding='utf-8').read()
    if paket:
        src = re.sub(r'^package\s+[\w.]+', 'package ' + paket, src, count=1, flags=re.M)
    for ad, deger in sabitler.items():
        # Soldaki kelime sınırı: adı bu sabitle BİTEN başka bir sabit
        # (ESKI_HEDEF_ADIM gibi) yanlışlıkla yeniden yazılmasın.
        src = re.sub(r'(?<![A-Za-z0-9_])(%s\s*=\s*)\d+' % ad,
                     r'\g<1>%d' % deger, src)
    open(yol, 'w', encoding='utf-8').write(src)


def kaynaklari_kopyala(here, proje):
    hedef_kotlin = kotlin_hedefi(proje)
    if not hedef_kotlin:
        print('   HATA: MainActivity.kt bulunamadı, Kotlin dosyaları konulamadı',
              file=sys.stderr)
        return False
    paket = paket_adi(hedef_kotlin)
    sabitler = su_sabitleri(here)
    for f in glob.glob(os.path.join(here, 'native/kotlin/*.kt')):
        varis = os.path.join(hedef_kotlin, os.path.basename(f))
        shutil.copy(f, varis)
        kotlini_uyarla(varis, paket, sabitler)
    print('   Kotlin dosyaları kopyalandı ->', os.path.relpath(hedef_kotlin, proje))
    print('   paket: %s' % (paket or '(değişmedi)'))
    print('   widget hedefleri: ' + ', '.join(
        '%s=%d' % (a, d) for a, d in sabitler.items()))

    res_kaynak = os.path.join(here, 'native/res')
    res_hedef = os.path.join(proje, 'android/app/src/main/res')
    for kok, _, dosyalar in os.walk(res_kaynak):
        rel = os.path.relpath(kok, res_kaynak)
        cikis = os.path.join(res_hedef, rel) if rel != '.' else res_hedef
        os.makedirs(cikis, exist_ok=True)
        for d in dosyalar:
            shutil.copy(os.path.join(kok, d), cikis)
    print('   res/ birleştirildi')
    return True


def gradle_yamala(proje):
    yol = os.path.join(proje, 'android/app/build.gradle.kts')
    groovy = False
    if not os.path.exists(yol):
        yol = os.path.join(proje, 'android/app/build.gradle')
        groovy = True
    if not os.path.exists(yol):
        print('   UYARI: build.gradle bulunamadı, bağımlılıklar eklenmedi',
              file=sys.stderr)
        return

    src = open(yol, encoding='utf-8').read()
    eklenecek = []
    for grup, surum in DEPS:
        if grup in src:
            continue
        if groovy:
            eklenecek.append("    implementation '%s:%s'" % (grup, surum))
        else:
            eklenecek.append('    implementation("%s:%s")' % (grup, surum))

    if not eklenecek:
        print('   gradle bağımlılıkları zaten ekli')
        return

    blok = '\n'.join(eklenecek)
    # Var olan dependencies bloğunun içine gir; yoksa dosyanın sonuna ekle.
    m = re.search(r'\ndependencies\s*\{', src)
    if m:
        src = src[:m.end()] + '\n' + blok + src[m.end():]
    else:
        src = src.rstrip() + '\n\ndependencies {\n' + blok + '\n}\n'
    open(yol, 'w', encoding='utf-8').write(src)
    print('   gradle bağımlılıkları eklendi:', ', '.join(g for g, _ in DEPS))


DESUGAR = ('com.android.tools:desugar_jdk_libs', '2.1.4')


def desugar_yamala(proje):
    """Bildirim eklentisi (flutter_local_notifications) Java 8+ API'lerini
    eski Android sürümlerinde de kullanabilmek için "desugaring" istiyor.
    İki yer: compileOptions içinde bayrak, dependencies içinde kitaplık."""
    yol = os.path.join(proje, 'android/app/build.gradle.kts')
    groovy = False
    if not os.path.exists(yol):
        yol = os.path.join(proje, 'android/app/build.gradle')
        groovy = True
    if not os.path.exists(yol):
        return
    src = open(yol, encoding='utf-8').read()
    onceki = src

    bayrak = ('coreLibraryDesugaringEnabled true' if groovy
              else 'isCoreLibraryDesugaringEnabled = true')
    if 'oreLibraryDesugaringEnabled' not in src:
        m = re.search(r'compileOptions\s*\{', src)
        if m:
            src = src[:m.end()] + '\n        ' + bayrak + src[m.end():]
        else:
            print('   UYARI: compileOptions bulunamadı, desugaring açılmadı',
                  file=sys.stderr)

    if DESUGAR[0] not in src:
        satir = ("    coreLibraryDesugaring '%s:%s'" if groovy
                 else '    coreLibraryDesugaring("%s:%s")') % DESUGAR
        m = re.search(r'\ndependencies\s*\{', src)
        if m:
            src = src[:m.end()] + '\n' + satir + src[m.end():]
        else:
            src = src.rstrip() + '\n\ndependencies {\n' + satir + '\n}\n'

    if src != onceki:
        open(yol, 'w', encoding='utf-8').write(src)
        print('   desugaring açıldı (bildirim eklentisi için)')


def main(proje):
    here = os.path.dirname(os.path.abspath(__file__))
    if not kaynaklari_kopyala(here, proje):
        return 1
    gradle_yamala(proje)
    desugar_yamala(proje)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
