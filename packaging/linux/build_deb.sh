#!/bin/bash
# Сборка DEB-пакета Robbo Junior (amd64): Debian, Ubuntu, Linux Mint, Astra.
#
#   packaging/linux/build_deb.sh
#
# Перед запуском: scripts/build.sh и scripts/fetch-runtime.sh linux
# Результат: packaging/linux/output/robboJunior_<версия>_amd64.deb
# DPKG_DEB_COMPRESS_LEVEL=6 — сильнее сжатие (по умолчанию 1, быстро).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"
source "$RJ_ROOT/scripts/lib/version.sh"

require_cmd dpkg-deb fakeroot

HERE="$RJ_PACKAGING/linux"
FILES="$HERE/files"
STAGE="$HERE/stage/deb"
OUTPUT="$HERE/output"
LEVEL="${DPKG_DEB_COMPRESS_LEVEL:-1}"

"$RJ_ROOT/scripts/sync-version.sh"
DEB_VERSION=$(rj_deb_version "$(rj_version)")
OUT_FILE="$OUTPUT/${RJ_PACKAGE_NAME}_${DEB_VERSION}_amd64.deb"

info "DEB $RJ_PACKAGE_NAME $DEB_VERSION"
rm -rf "$STAGE"
ROOT="$STAGE/root"
APP="$ROOT$RJ_INSTALL_DIR_LINUX"

"$RJ_ROOT/scripts/stage-app.sh" linux "$APP"

install -m 755 "$FILES/robboJunior-launcher.sh" "$APP/robboJunior"
install -m 755 "$FILES/create_shortcut.sh" "$APP/create_shortcut.sh"
install -D -m 755 /dev/stdin "$ROOT/usr/bin/robboJunior" <<EOF
#!/bin/bash
exec $RJ_INSTALL_DIR_LINUX/robboJunior "\$@"
EOF
install -D -m 644 "$FILES/robboJunior.desktop" "$ROOT/usr/share/applications/robboJunior.desktop"
install -D -m 644 "$RJ_PACKAGING/common/icons/robbojunior.png" "$ROOT/usr/share/pixmaps/robboJunior.png"
install -D -m 644 "$FILES/86-robbojunior-ch340.rules" "$ROOT/usr/lib/udev/rules.d/86-robbojunior-ch340.rules"

# Права: каталоги 755, исполняемые остаются исполняемыми, остальное 644
find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f ! -perm -u+x -exec chmod 644 {} +
find "$ROOT" -type f -perm -u+x -exec chmod 755 {} +

# DEBIAN: control (+ Installed-Size), postinst и postrm из общих скриптов
mkdir -p "$ROOT/DEBIAN"
SIZE_KB=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
sed "/^Version:/a Installed-Size: $SIZE_KB" "$HERE/deb_package/DEBIAN/control" >"$ROOT/DEBIAN/control"
grep -q "^Version: $DEB_VERSION\$" "$ROOT/DEBIAN/control" || die "версия в control не $DEB_VERSION"

{
    echo '#!/bin/bash'
    echo 'set -e'
    echo '[ "$1" = "configure" ] || exit 0'
    sed '1d' "$FILES/post-install.sh"
} >"$ROOT/DEBIAN/postinst"
{
    echo '#!/bin/bash'
    echo 'set -e'
    echo 'case "$1" in remove|purge) ;; *) exit 0 ;; esac'
    sed '1d' "$FILES/post-remove.sh"
} >"$ROOT/DEBIAN/postrm"
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"

mkdir -p "$OUTPUT"
rm -f "$OUT_FILE"
info "Упаковываю (gzip -$LEVEL)"
fakeroot dpkg-deb -Zgzip -z"$LEVEL" --build "$ROOT" "$OUT_FILE" >/dev/null

# Проверка: пакет читается и в нём есть ключевые файлы
CONTENTS=$(dpkg-deb -c "$OUT_FILE")
for f in "opt/robboJunior/jr/junior" "opt/robboJunior/jr/resources/app/app.bundle.js" \
    "opt/robboJunior/java/bin/java" "opt/robboJunior/lib/i-robot.jar" "opt/robboJunior/robboJunior" \
    "usr/bin/robboJunior" "usr/share/applications/robboJunior.desktop"; do
    echo "$CONTENTS" | grep -q " \./$f\$" || die "в пакете нет $f"
done
require_min_size "$OUT_FILE" 50000000

rm -rf "$STAGE"
info "Готово: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
