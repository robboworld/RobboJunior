#!/bin/bash
# Сборка RPM-пакета Robbo Junior (x86_64): Альт, РЕД ОС, Fedora, openSUSE.
#
#   packaging/linux/build_rpm.sh
#
# Перед запуском: scripts/build.sh и scripts/fetch-runtime.sh linux
# Результат: packaging/linux/output/robboJunior-<версия>-<релиз>.x86_64.rpm
# Нужен rpmbuild (Ubuntu: sudo apt install rpm).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"
source "$RJ_ROOT/scripts/lib/version.sh"

require_cmd rpmbuild

HERE="$RJ_PACKAGING/linux"
FILES="$HERE/files"
STAGE="$HERE/stage/rpm"
TOPDIR="$HERE/rpmbuild"
OUTPUT="$HERE/output"

"$RJ_ROOT/scripts/sync-version.sh"
VERSION=$(rj_version)
RPM_VERSION=$(rj_rpm_version "$VERSION")
RPM_RELEASE=$(rj_rpm_release "$VERSION")

info "RPM $RJ_PACKAGE_NAME $RPM_VERSION-$RPM_RELEASE"
rm -rf "$STAGE" "$TOPDIR"
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

find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f ! -perm -u+x -exec chmod 644 {} +
find "$ROOT" -type f -perm -u+x -exec chmod 755 {} +

# Имена .so внутри пакета: rpm не должен требовать их от системы.
# В spec обратная косая черта удваивается (раскрытие макросов rpm): libstdc\\+\\+\\.so.*
BUNDLED=$(find "$APP" -name '*.so*' -type f -printf '%f\n' | sed -E 's/\.so.*$//' | sort -u |
    sed -E 's/([.+])/\\\\\1/g' | tr '\n' '|' | sed 's/|$//')
[ -n "$BUNDLED" ] || die "в дереве установки не найдено ни одной .so — раскладка неполная?"
export RJ_BUNDLED_RE="|(${BUNDLED})\\\\.so.*"
export RJ_RPM_VERSION="$RPM_VERSION" RJ_RPM_RELEASE="$RPM_RELEASE"
export RJ_POST_INSTALL RJ_POST_REMOVE
RJ_POST_INSTALL=$(sed '1{/^#!/d}' "$FILES/post-install.sh")
RJ_POST_REMOVE=$(sed '1{/^#!/d}' "$FILES/post-remove.sh")

# Подстановка через awk и ENVIRON — значения не нужно экранировать
SPEC="$STAGE/robboJunior.spec"
awk '
    /^%define version / { print "%define version " ENVIRON["RJ_RPM_VERSION"]; next }
    /^%define release / { print "%define release " ENVIRON["RJ_RPM_RELEASE"]; next }
    index($0, "@POST_INSTALL@") { print ENVIRON["RJ_POST_INSTALL"]; next }
    index($0, "@POST_REMOVE@")  { print ENVIRON["RJ_POST_REMOVE"]; next }
    {
        i = index($0, "@BUNDLED_LIBS@")
        if (i) $0 = substr($0, 1, i - 1) ENVIRON["RJ_BUNDLED_RE"] substr($0, i + length("@BUNDLED_LIBS@"))
        print
    }' "$HERE/rpm_package/robboJunior.spec" >"$SPEC"
if grep -n '@[A-Z_]*@' "$SPEC"; then
    die "в spec остались неподставленные метки"
fi

info "rpmbuild"
rpmbuild -bb \
    --define "_topdir $TOPDIR" \
    --define "rj_stage $ROOT" \
    --define "_binary_payload w1.gzdio" \
    "$SPEC" >"$STAGE/rpmbuild.log" 2>&1 || {
    tail -40 "$STAGE/rpmbuild.log"
    die "rpmbuild завершился с ошибкой (полный лог: $STAGE/rpmbuild.log)"
}

RPM_FILE=$(find "$TOPDIR/RPMS" -name "${RJ_PACKAGE_NAME}-${RPM_VERSION}-${RPM_RELEASE}.x86_64.rpm" | head -1)
[ -n "$RPM_FILE" ] || die "rpmbuild не создал пакет"
mkdir -p "$OUTPUT"
mv "$RPM_FILE" "$OUTPUT/"
OUT_FILE="$OUTPUT/$(basename "$RPM_FILE")"

# Проверка: ключевые файлы на месте, зависимостей от встроенных библиотек нет
LIST=$(rpm -qlp "$OUT_FILE" 2>/dev/null)
for f in /opt/robboJunior/jr/junior /opt/robboJunior/java/bin/java /opt/robboJunior/lib/i-robot.jar /usr/bin/robboJunior; do
    echo "$LIST" | grep -qx "$f" || die "в пакете нет $f"
done
if rpm -qpR "$OUT_FILE" 2>/dev/null | grep -qE '^(libjvm|libjli|libffmpeg)'; then
    die "пакет требует встроенные библиотеки от системы: $(rpm -qpR "$OUT_FILE" | grep -E '^(libjvm|libjli|libffmpeg)' | tr '\n' ' ')"
fi
require_min_size "$OUT_FILE" 50000000

rm -rf "$STAGE" "$TOPDIR"
info "Готово: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
