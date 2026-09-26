#!/usr/bin/env bash
# Kerteriz — sıfırdan kurulup APK üretir.
# Kullanım: bash apk-olustur.sh
# Çıktı:    ../kerteriz/build/app/outputs/flutter-apk/app-release.apk
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../kerteriz}"

if [ ! -d "$OUT" ]; then
  bash "$HERE/kurulum.sh" "$OUT"
fi

cd "$OUT"
echo "==> flutter doctor"
flutter doctor -v || true

echo "==> APK derleniyor (release, varsayılan debug imzasıyla)"
flutter build apk --release

APK="$OUT/build/app/outputs/flutter-apk/app-release.apk"
echo
if [ -f "$APK" ]; then
  echo "Hazır: $APK"
  echo "Telefon USB ile bağlıysa doğrudan kurmak için:"
  echo "  flutter install --release"
else
  echo "APK üretilemedi; yukarıdaki Gradle çıktısına bak."
fi
