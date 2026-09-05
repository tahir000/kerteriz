#!/usr/bin/env bash
# Kerteriz — Flutter iskeletini calisir projeye cevirir.
# Kullanim:  bash kurulum.sh  (bu klasorun icinde, Flutter SDK kurulu olmali)
#
# Onemli: Android tarafindaki dosyalarin UZERINE YAZMAZ. Flutter'in urettigi
# manifest ve MainActivity, o Flutter surumunun bekledigi yapilandirmayi zaten
# dogru tasir; biz yalnizca Health Connect icin gerekenleri ekliyoruz.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../kerteriz}"

echo "==> Flutter projesi olusturuluyor: $OUT"
flutter create --org com.kerteriz --project-name kerteriz "$OUT"

echo "==> Dart kaynagi kopyalaniyor"
rm -rf "$OUT/lib"
cp -R "$HERE/lib" "$OUT/lib"
cp "$HERE/pubspec.yaml" "$OUT/pubspec.yaml"
cp "$HERE/analysis_options.yaml" "$OUT/analysis_options.yaml"

# flutter create ornek bir test birakir; o test MyApp arar, bizim sinifimiz
# KerterizApp oldugu icin analizor hata verir.
rm -f "$OUT/test/widget_test.dart"

echo "==> AndroidManifest yamalaniyor (Health Connect izinleri)"
python3 "$HERE/patch_manifest.py" "$OUT/android/app/src/main/AndroidManifest.xml"

echo "==> MainActivity yamalaniyor (FlutterFragmentActivity)"
python3 "$HERE/patch_mainactivity.py" "$OUT"

echo "==> Uygulama ikonu yerlestiriliyor"
for D in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  SRC="$HERE/android-icons/mipmap-$D/ic_launcher.png"
  DST="$OUT/android/app/src/main/res/mipmap-$D"
  if [ -f "$SRC" ] && [ -d "$DST" ]; then
    cp "$SRC" "$DST/ic_launcher.png"
  fi
done

echo "==> minSdk 28'e cekiliyor"
GRADLE_KTS="$OUT/android/app/build.gradle.kts"
GRADLE_GROOVY="$OUT/android/app/build.gradle"
if [ -f "$GRADLE_KTS" ]; then
  sed -i.bak -E 's/minSdk *= *[^ ]+/minSdk = 28/' "$GRADLE_KTS"
  rm -f "$GRADLE_KTS.bak"
elif [ -f "$GRADLE_GROOVY" ]; then
  sed -i.bak -E 's/minSdkVersion .*/minSdkVersion 28/' "$GRADLE_GROOVY"
  rm -f "$GRADLE_GROOVY.bak"
fi

echo "==> Bagimliliklar"
cd "$OUT"
flutter pub get

echo
echo "Bitti. Telefonu USB ile bagla, sonra:"
echo "  cd $OUT && flutter run"
