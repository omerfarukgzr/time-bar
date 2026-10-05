#!/bin/bash
# Time Bar'ı derler ve dist/ klasörüne "Time Bar.app" ile yayın zip'ini üretir.
#   scripts/build.sh            → derle ve paketle
#   scripts/build.sh --install  → ayrıca ~/Applications'a kur ve başlat
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
# .noindex: Spotlight bu klasöre bakmaz, yoksa kurulu uygulamanın yanında ikinci bir kopya görünür
APP="dist/app.noindex/Time Bar.app"

# Apple Silicon + Intel için tek dosya
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/TimeBar"

# İkon
if [ ! -f Resources/AppIcon.icns ]; then
  TMP=$(mktemp -d)
  swift scripts/make_icon.swift "$TMP/icon.png"
  mkdir "$TMP/AppIcon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
  sips -z 256 256 "$TMP/icon.png" --out docs/icon.png >/dev/null
  rm -rf "$TMP"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TimeBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"

# Sürüm numarası adda yok: README'deki releases/latest/download/TimeBar.zip linki hep son sürümü indirsin
ZIP="dist/TimeBar.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Hazır: $APP"
echo "Yayın dosyası: $ZIP (sürüm $VERSION)"

if [ "${1:-}" = "--install" ]; then
  pkill -f "Time Bar.app/Contents/MacOS/TimeBar$" 2>/dev/null || true
  sleep 0.5
  rm -rf "$HOME/Applications/Time Bar.app"
  mkdir -p "$HOME/Applications"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/Time Bar.app"
  echo "Kuruldu: ~/Applications/Time Bar.app"
fi
