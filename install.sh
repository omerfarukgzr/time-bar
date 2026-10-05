#!/bin/bash
# Time Bar'ı kurar ya da son sürüme günceller:
#   curl -fsSL https://raw.githubusercontent.com/omerfarukgzr/time-bar/main/install.sh | bash
# curl ile inen dosyaya karantina işareti konmadığı için macOS'un "doğrulanamadı" uyarısı çıkmaz.
set -euo pipefail

REPO="omerfarukgzr/time-bar"
APP_NAME="Time Bar.app"

# Her şey bir fonksiyonun içinde: bağlantı yarıda koparsa yarım script çalışmasın
main() {
  [ "$(uname)" = "Darwin" ] || { echo "Time Bar sadece macOS'ta çalışır." >&2; exit 1; }

  # Daha önce ~/Applications'a kurulduysa orada güncelle; yoksa /Applications, yazılamıyorsa ~/Applications
  if [ -d "$HOME/Applications/$APP_NAME" ]; then
    DEST="$HOME/Applications"
  elif [ -w /Applications ]; then
    DEST="/Applications"
  else
    DEST="$HOME/Applications"
  fi

  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  echo "Son sürüm aranıyor…"
  URL="https://github.com/$REPO/releases/latest/download/TimeBar.zip"
  DIGEST=""
  if curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" -o "$TMP/release.json" 2>/dev/null; then
    count=$(plutil -extract assets raw -o - "$TMP/release.json" 2>/dev/null || echo 0)
    for ((i = 0; i < count; i++)); do
      if [ "$(plutil -extract "assets.$i.name" raw -o - "$TMP/release.json")" = "TimeBar.zip" ]; then
        URL=$(plutil -extract "assets.$i.browser_download_url" raw -o - "$TMP/release.json")
        DIGEST=$(plutil -extract "assets.$i.digest" raw -o - "$TMP/release.json" 2>/dev/null || true)
        DIGEST=${DIGEST#sha256:}
      fi
    done
  fi

  # Uygulamanın kendi güncelleyicisi gibi: doğrulanamayan dosya kurulmaz
  [ -n "$DIGEST" ] || { echo "Sürümün SHA-256 özeti GitHub'dan alınamadı, kurulum iptal edildi. Biraz sonra tekrar dene." >&2; exit 1; }

  echo "İndiriliyor…"
  curl -fL --progress-bar "$URL" -o "$TMP/TimeBar.zip"

  actual=$(shasum -a 256 "$TMP/TimeBar.zip" | cut -d' ' -f1)
  if [ "$actual" != "$DIGEST" ]; then
    echo "İndirilen dosya doğrulanamadı (SHA-256 uyuşmuyor). Kurulum iptal edildi." >&2
    exit 1
  fi

  ditto -x -k "$TMP/TimeBar.zip" "$TMP/unpacked"
  [ -d "$TMP/unpacked/$APP_NAME" ] || { echo "Zip'te $APP_NAME bulunamadı." >&2; exit 1; }
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$TMP/unpacked/$APP_NAME/Contents/Info.plist")

  # Açıksa kapat. Süren sayaç ve geçmiş kayıtlı, yeni sürüm açılınca kaldığı yerden devam eder.
  if pgrep -f "$APP_NAME/Contents/MacOS/TimeBar$" >/dev/null; then
    echo "Açık olan Time Bar kapatılıyor…"
    osascript -e 'quit app "Time Bar"' >/dev/null 2>&1 || true
    for _ in {1..20}; do
      pgrep -f "$APP_NAME/Contents/MacOS/TimeBar$" >/dev/null || break
      sleep 0.25
    done
    pkill -f "$APP_NAME/Contents/MacOS/TimeBar$" 2>/dev/null || true
  fi

  mkdir -p "$DEST"
  rm -rf "$DEST/$APP_NAME"
  mv "$TMP/unpacked/$APP_NAME" "$DEST/"
  xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

  open "$DEST/$APP_NAME"
  echo "Time Bar $VERSION kuruldu: $DEST/$APP_NAME"
  echo "Menü çubuğundaki ikona bak."
}

main "$@"
