#!/usr/bin/env bash
# Kerteriz — Flutter iskeletini çalışır projeye çevirir.
# Kullanım:  bash kurulum.sh  (bu klasörün içinde, Flutter SDK kurulu olmalı)
#
# Önemli: Android tarafındaki dosyaların ÜZERİNE YAZMAZ. Flutter'ın ürettiği
# manifest ve MainActivity, o Flutter sürümünün beklediği yapılandırmayı zaten
# doğru taşır; biz yalnızca Health Connect için gerekenleri ekliyoruz.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../kerteriz}"

echo "==> Flutter projesi oluşturuluyor: $OUT"
flutter create --org com.kerteriz --project-name kerteriz "$OUT"

echo "==> Dart kaynağı kopyalanıyor"
rm -rf "$OUT/lib"
cp -R "$HERE/lib" "$OUT/lib"
cp "$HERE/pubspec.yaml" "$OUT/pubspec.yaml"
cp "$HERE/analysis_options.yaml" "$OUT/analysis_options.yaml"

# flutter create örnek bir test bırakır; o test MyApp arar, bizim sınıfımız
# KerterizApp olduğu için analizör hata verir.
rm -f "$OUT/test/widget_test.dart"

echo "==> AndroidManifest yamalanıyor (Health Connect izinleri)"
python3 "$HERE/patch_manifest.py" "$OUT/android/app/src/main/AndroidManifest.xml"

echo "==> MainActivity yamalanıyor (FlutterFragmentActivity)"
python3 "$HERE/patch_mainactivity.py" "$OUT"

echo "==> Su widget'ı yerleştiriliyor (native Kotlin + kaynaklar)"
python3 "$HERE/patch_native.py" "$OUT"

echo "==> Uygulama ikonu yerleştiriliyor"
for D in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  SRC="$HERE/android-icons/mipmap-$D/ic_launcher.png"
  DST="$OUT/android/app/src/main/res/mipmap-$D"
  if [ -f "$SRC" ] && [ -d "$DST" ]; then
    cp "$SRC" "$DST/ic_launcher.png"
  fi
done

echo "==> minSdk 28'e çekiliyor"
GRADLE_KTS="$OUT/android/app/build.gradle.kts"
GRADLE_GROOVY="$OUT/android/app/build.gradle"
if [ -f "$GRADLE_KTS" ]; then
  sed -i.bak -E 's/minSdk *= *[^ ]+/minSdk = 28/' "$GRADLE_KTS"
  rm -f "$GRADLE_KTS.bak"
elif [ -f "$GRADLE_GROOVY" ]; then
  sed -i.bak -E 's/minSdkVersion .*/minSdkVersion 28/' "$GRADLE_GROOVY"
  rm -f "$GRADLE_GROOVY.bak"
fi

echo "==> Bağımlılıklar"
cd "$OUT"
flutter pub get

echo
echo "Bitti. Telefonu USB ile bağla, sonra:"
echo "  cd $OUT && flutter run"
