#!/bin/bash
# Переносит версию из CHANGELOG.md во все места, где она записана.
#
#   scripts/sync-version.sh          записать версию
#   scripts/sync-version.sh --check  только проверить (код 1, если где-то расходится)
#   scripts/sync-version.sh --print  вывести VERSION, DEB_VERSION, RPM_VERSION, RPM_RELEASE, ANDROID_VERSION_CODE
#
# RJ_VERSION=1.2.3 — взять версию отсюда вместо CHANGELOG.md.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/version.sh"

MODE="${1:-sync}"

VERSION=$(rj_version)
DEB_VERSION=$(rj_deb_version "$VERSION")
RPM_VERSION=$(rj_rpm_version "$VERSION")
RPM_RELEASE=$(rj_rpm_release "$VERSION")
ANDROID_VERSION_CODE=$(rj_android_version_code "$VERSION")

if [ "$MODE" = "--print" ]; then
    echo "VERSION=$VERSION"
    echo "DEB_VERSION=$DEB_VERSION"
    echo "RPM_VERSION=$RPM_VERSION"
    echo "RPM_RELEASE=$RPM_RELEASE"
    echo "ANDROID_VERSION_CODE=$ANDROID_VERSION_CODE"
    exit 0
fi

[ "$MODE" = "sync" ] || [ "$MODE" = "--check" ] || die "неизвестный режим '$MODE' (нужно: без аргументов, --check или --print)"

# Каждая цель: файл | regex для поиска строки | строка, которая должна быть
# Строки ищутся по началу (якорю), заменяется вся строка целиком.
TARGETS=(
    "desktop/package.json|^  \"version\": \".*\",\$|  \"version\": \"$VERSION\","
    "desktop/version|^Version: .*\$|Version: robbojunior (desktop) $VERSION"
    "desktop/home.html|^( *)<span id=\"version\">v .*</span>\$|\\1<span id=\"version\">v $VERSION</span>"
    "packaging/linux/deb_package/DEBIAN/control|^Version: .*\$|Version: $DEB_VERSION"
    "packaging/linux/rpm_package/robboJunior.spec|^%define version .*\$|%define version $RPM_VERSION"
    "packaging/linux/rpm_package/robboJunior.spec|^%define release .*\$|%define release $RPM_RELEASE"
    "packaging/windows/RobboJunior.nsi|^!define VERSION .*\$|!define VERSION \"$VERSION\""
)

mismatch=0
for t in "${TARGETS[@]}"; do
    IFS='|' read -r rel pattern replacement <<<"$t"
    file="$RJ_ROOT/$rel"
    if [ ! -f "$file" ]; then
        echo "  пропуск: нет файла $rel"
        continue
    fi
    grep -qE "$pattern" "$file" || die "в $rel нет строки, подходящей под /$pattern/"
    if [ "$MODE" = "--check" ]; then
        current=$(grep -m1 -E "$pattern" "$file")
        expected=$(echo "$current" | sed -E "s|$pattern|$replacement|")
        if [ "$current" != "$expected" ]; then
            echo "  расходится: $rel: '$current' (нужно '$expected')"
            mismatch=1
        fi
    else
        sed -i -E "s|$pattern|$replacement|" "$file"
    fi
done

if [ "$MODE" = "--check" ]; then
    if [ "$mismatch" -ne 0 ]; then
        echo "Версии не совпадают с CHANGELOG.md ($VERSION). Запустите scripts/sync-version.sh"
        exit 1
    fi
    echo "Версия $VERSION совпадает во всех файлах"
else
    echo "Версия $VERSION записана (deb $DEB_VERSION, rpm $RPM_VERSION-$RPM_RELEASE)"
fi
