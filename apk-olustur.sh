#!/usr/bin/env bash
# Kerteriz — sifirdan kurulup APK uretir.
# Kullanim: bash apk-olustur.sh
# Cikti:    ../kerteriz/build/app/outputs/flutter-apk/app-release.apk
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../kerteriz}"

if [ ! -d "$OUT" ]; then
  bash "$HERE/kurulum.sh" "$OUT"
fi

cd "$OUT"
echo "==> flutter doctor"
flutter doctor -v || true

echo "==> APK derleniyor (release, varsayilan debug imzasiyla)"
flutter build apk --release

APK="$OUT/build/app/outputs/flutter-apk/app-release.apk"
echo
if [ -f "$APK" ]; then
  echo "Hazir: $APK"
  echo "Telefon USB ile bagliysa dogrudan kurmak icin:"
  echo "  flutter install --release"
else
  echo "APK uretilemedi; yukaridaki Gradle ciktisina bak."
fi
