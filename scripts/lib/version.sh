#!/bin/bash
# Версия RobboJunior: чтение из CHANGELOG.md и преобразование в форматы пакетов.
# Правила те же, что у RobboScratch (RS3_Assembly/scripts/sync-version.sh):
#   CHANGELOG      deb            rpm version-release   NSIS / приложение
#   X.Y.Z          X.Y.Z          X.Y.Z-1               X.Y.Z
#   X.Y.Z-alpha    X.Y.Z~alpha    X.Y.Z-alpha           X.Y.Z-alpha
#   X.Y.Z-N        X.Y.Z-N        X.Y.Z-N               X.Y.Z-N

# Верхний заголовок "## [X.Y.Z...]" из CHANGELOG.md (или $RJ_VERSION, если задана)
rj_version() {
    if [ -n "${RJ_VERSION:-}" ]; then
        echo "$RJ_VERSION"
        return
    fi
    local v
    v=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?\]' "$RJ_ROOT/CHANGELOG.md" | sed -E 's/^## \[(.*)\]$/\1/')
    [ -n "$v" ] || die "в CHANGELOG.md нет заголовка вида '## [X.Y.Z]'"
    echo "$v"
}

# X.Y.Z — без суффикса
rj_version_base() {
    echo "${1%%-*}"
}

# Суффикс после первого '-', пусто если нет
rj_version_suffix() {
    case "$1" in
        *-*) echo "${1#*-}" ;;
        *) echo "" ;;
    esac
}

rj_deb_version() {
    local base suffix
    base=$(rj_version_base "$1")
    suffix=$(rj_version_suffix "$1")
    if [ -z "$suffix" ]; then
        echo "$base"
    elif [[ "$suffix" =~ ^[0-9]+$ ]]; then
        echo "$base-$suffix"
    else
        # тильда: 1.0.0~alpha сортируется раньше 1.0.0
        echo "$base~$suffix"
    fi
}

rj_rpm_version() {
    rj_version_base "$1"
}

rj_rpm_release() {
    local suffix
    suffix=$(rj_version_suffix "$1")
    echo "${suffix:-1}"
}

# Android versionCode: целое, растёт с версией. X*10000 + Y*100 + Z, ×100 + номер сборки/0
# Предварительные версии (-alpha) получают на 1 меньше финальной.
rj_android_version_code() {
    local base suffix major minor patch code
    base=$(rj_version_base "$1")
    suffix=$(rj_version_suffix "$1")
    IFS=. read -r major minor patch <<<"$base"
    code=$(( (major * 10000 + minor * 100 + patch) * 100 + 50 ))
    if [ -z "$suffix" ]; then
        :
    elif [[ "$suffix" =~ ^[0-9]+$ ]]; then
        code=$((code + suffix))
    else
        code=$((code - 1))
    fi
    echo "$code"
}
