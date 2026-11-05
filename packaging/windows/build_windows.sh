#!/bin/bash
# Сборка установщика Robbo Junior для Windows x64 (NSIS). Запускается на Linux.
#
#   packaging/windows/build_windows.sh
#   WIN_COMPRESSOR=lzma packaging/windows/build_windows.sh   # меньше размер, дольше сборка (для релиза)
#
# Перед запуском: scripts/build.sh и scripts/fetch-runtime.sh windows
# Нужен makensis 3.x (Ubuntu: sudo apt install nsis).
# Результат: packaging/windows/output/robboJunior-<версия>-x64.exe

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"
source "$RJ_ROOT/scripts/lib/version.sh"

require_cmd makensis

HERE="$RJ_PACKAGING/windows"
STAGE="$HERE/stage/robboJunior"
OUTPUT="$HERE/output"
COMPRESSOR="${WIN_COMPRESSOR:-zlib}"
[ "$COMPRESSOR" = "zlib" ] || [ "$COMPRESSOR" = "lzma" ] || die "WIN_COMPRESSOR: zlib или lzma"

"$RJ_ROOT/scripts/sync-version.sh"
VERSION=$(rj_version)
OUT_FILE="$OUTPUT/${RJ_PACKAGE_NAME}-${VERSION}-x64.exe"

info "Windows $RJ_PACKAGE_NAME $VERSION ($COMPRESSOR)"
"$RJ_ROOT/scripts/stage-app.sh" windows "$STAGE"
[ -f "$STAGE/java/bin/javaw.exe" ] || die "в раскладке нет java/bin/javaw.exe"

grep -q "^!define VERSION \"$VERSION\"" "$HERE/RobboJunior.nsi" || die "версия в RobboJunior.nsi не $VERSION"

mkdir -p "$OUTPUT"
rm -f "$OUT_FILE"
makensis -V2 \
    -DSTAGE_DIR="$STAGE" \
    -DDRIVERS_DIR="$RJ_PACKAGING/common/drivers" \
    -DICON_FILE="$RJ_PACKAGING/common/icons/robbojunior.ico" \
    -DOUT_FILE="$OUT_FILE" \
    -DROBBO_COMPRESSOR="$COMPRESSOR" \
    "$HERE/RobboJunior.nsi"

require_min_size "$OUT_FILE" 50000000
rm -rf "$HERE/stage"
info "Готово: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
