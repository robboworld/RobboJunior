#!/bin/bash
# Раскладывает готовое к установке дерево RobboJunior для одной ОС:
#
#   <dest>/
#     jr/junior(.exe)        Electron, переименованный (панель запускает именно jr/junior)
#     jr/resources/app/      GUI из desktop/ (без исходников и node_modules)
#     java/                  Java 8 (Temurin)
#     lib/  config.ini  i18n.*  firmware/   — Java-панель (packaging/common/panel)
#
#   scripts/stage-app.sh linux|windows <dest>
#
# Перед запуском: scripts/build.sh (бандл) и scripts/fetch-runtime.sh <os>.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/fetch-runtime.sh"

OS="${1:-}"
DEST="${2:-}"
[ "$OS" = "linux" ] || [ "$OS" = "windows" ] || die "использование: scripts/stage-app.sh linux|windows <dest>"
[ -n "$DEST" ] || die "не указан каталог назначения"

check_runtime "$OS"
require_min_size "$RJ_DESKTOP/app.bundle.js" 1000000
grep -q '^const node_fs = require("fs");' "$RJ_DESKTOP/app.bundle.js" || die "desktop/app.bundle.js собран не через scripts/build.sh"

RT="$RJ_RUNTIME/$OS"
PANEL="$RJ_PACKAGING/common/panel"

info "Раскладка для $OS → $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"

# Electron → jr/
cp -R "$RT/electron" "$DEST/jr"
rm -f "$DEST/jr/resources/default_app.asar"
case "$OS" in
    linux) mv "$DEST/jr/electron" "$DEST/jr/junior" ;;
    windows) mv "$DEST/jr/electron.exe" "$DEST/jr/junior.exe" ;;
esac
# Лишние локали Chromium: оставляем английскую и русскую
find "$DEST/jr/locales" -name '*.pak' ! -name 'en-US.pak' ! -name 'ru.pak' -delete

# GUI → jr/resources/app/
APP="$DEST/jr/resources/app"
mkdir -p "$APP"
(cd "$RJ_DESKTOP" && tar -cf - \
    --exclude=./src \
    --exclude=./node_modules \
    --exclude=./package-lock.json \
    --exclude=./.npmrc \
    --exclude=./app.bundle.js.map \
    --exclude=./webpack.config.js \
    .) | (cd "$APP" && tar -xf -)
require_min_size "$APP/app.bundle.js" 1000000
[ -f "$APP/index.html" ] && [ -f "$APP/main.js" ] && [ -f "$APP/package.json" ] || die "в $APP нет index.html/main.js/package.json"

# Java 8 → java/
cp -R "$RT/jre" "$DEST/java"

# Панель
cp -R "$PANEL/lib" "$DEST/lib"
cp "$PANEL/config.ini" "$DEST/"
cp "$PANEL"/i18n.* "$DEST/"
mkdir -p "$DEST/firmware"
cp "$PANEL/firmware/avrdude.conf" "$PANEL"/firmware/diagnostics.* "$DEST/firmware/"
cp -R "$PANEL/firmware/devices" "$DEST/firmware/devices"
if [ "$OS" = "windows" ]; then
    cp -R "$PANEL/firmware/win" "$DEST/firmware/win"
fi
require_min_size "$DEST/lib/i-robot.jar" 500000
[ -f "$DEST/lib/jssc-2.9.6.jar" ] || die "нет lib/jssc-2.9.6.jar"

echo "$(cat "$RT/runtime-version.txt")" >"$DEST/runtime-version.txt"
info "Раскладка готова: $(du -sh "$DEST" | cut -f1)"
