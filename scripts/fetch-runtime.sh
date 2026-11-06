#!/bin/bash
# Скачивает runtime для пакетов в runtime/<os>/ (вне git) с проверкой sha256:
#   electron/  — Electron (оболочка GUI)
#   jre/       — Java 8 (Temurin) для панели управления роботом
#
#   scripts/fetch-runtime.sh linux|windows|all
#
# Версии и контрольные суммы закреплены ниже. Чтобы обновить — поменяйте их здесь
# (суммы: SHASUMS256.txt релиза Electron; api.adoptium.net для Temurin).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ELECTRON_VERSION="17.4.11"
ELECTRON_SHA256_linux="c40cc41da8f7958b4edbef953e9b0b4e830689467d1f1993c4d298677e6d0047"
ELECTRON_SHA256_windows="40f89fd5bd3aa59911e80c10d580cd7133d81693c702a933dd0f4c78e064566c"

# Java 8 обязательна: панель (Spring 4.1, Jersey 1.5) использует JAXB, которого нет в Java 11+
JRE_TAG="jdk8u512-b09"
JRE_FILE_linux="OpenJDK8U-jre_x64_linux_hotspot_8u512b09.tar.gz"
JRE_SHA256_linux="57468dc8bfd71dd0578d9717e63a8c13b9efe0a2f2c85c2a13966d1c0f9b1e5f"
JRE_FILE_windows="OpenJDK8U-jre_x64_windows_hotspot_8u512b09.zip"
JRE_SHA256_windows="ae1ae12f817d7735477c6555107eece73854da0654da69077309ef9bff0b78bf"

# Маркер: по нему build_* проверяют, что runtime нужной версии
RUNTIME_MARKER="electron=$ELECTRON_VERSION jre=$JRE_TAG"

CACHE="$RJ_RUNTIME/.downloads"

download() {
    local url="$1" out="$2" sha="$3"
    if [ -f "$out" ] && [ "$(sha256_of "$out")" = "$sha" ]; then
        echo "  уже скачан: $(basename "$out")"
        return
    fi
    echo "  скачиваю $url"
    curl -fsSL --retry 5 --retry-delay 3 -o "$out.part" "$url" || die "не удалось скачать $url"
    local got
    got=$(sha256_of "$out.part")
    if [ "$got" != "$sha" ]; then
        rm -f "$out.part"
        die "sha256 не совпадает для $(basename "$out"): $got (ожидалось $sha)"
    fi
    mv "$out.part" "$out"
}

fetch_os() {
    local os="$1" eplat earchive jfile jsha esha dest
    case "$os" in
        linux) eplat="linux-x64" ;;
        windows) eplat="win32-x64" ;;
        *) die "неизвестная ОС '$os'" ;;
    esac
    eval "esha=\$ELECTRON_SHA256_$os"
    eval "jfile=\$JRE_FILE_$os"
    eval "jsha=\$JRE_SHA256_$os"
    earchive="electron-v$ELECTRON_VERSION-$eplat.zip"
    dest="$RJ_RUNTIME/$os"

    if [ -f "$dest/runtime-version.txt" ] && [ "$(cat "$dest/runtime-version.txt")" = "$RUNTIME_MARKER" ]; then
        info "runtime/$os уже актуален ($RUNTIME_MARKER)"
        return
    fi

    info "runtime/$os: Electron $ELECTRON_VERSION, Java $JRE_TAG"
    mkdir -p "$CACHE"
    download "https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/$earchive" "$CACHE/$earchive" "$esha"
    download "https://github.com/adoptium/temurin8-binaries/releases/download/$JRE_TAG/$jfile" "$CACHE/$jfile" "$jsha"

    rm -rf "$dest"
    mkdir -p "$dest/electron" "$dest/jre.tmp"
    unzip -q "$CACHE/$earchive" -d "$dest/electron"
    case "$jfile" in
        *.zip) unzip -q "$CACHE/$jfile" -d "$dest/jre.tmp" ;;
        *.tar.gz) tar -xzf "$CACHE/$jfile" -C "$dest/jre.tmp" ;;
    esac
    # в архиве один каталог верхнего уровня (jdk8u…-jre) — поднимаем его содержимое
    mv "$dest/jre.tmp"/*/ "$dest/jre"
    rm -rf "$dest/jre.tmp"

    case "$os" in
        linux)
            require_min_size "$dest/electron/electron" 50000000
            require_min_size "$dest/jre/bin/java" 5000
            ;;
        windows)
            require_min_size "$dest/electron/electron.exe" 50000000
            require_min_size "$dest/jre/bin/java.exe" 50000
            ;;
    esac
    echo "$RUNTIME_MARKER" >"$dest/runtime-version.txt"
    info "runtime/$os готов"
}

# Для build_*: убедиться, что runtime скачан и нужной версии
check_runtime() {
    local os="$1" marker="$RJ_RUNTIME/$1/runtime-version.txt"
    [ -f "$marker" ] || die "нет runtime/$os. Выполните: scripts/fetch-runtime.sh $os"
    [ "$(cat "$marker")" = "$RUNTIME_MARKER" ] || die "runtime/$os устарел ($(cat "$marker"), нужно $RUNTIME_MARKER). Выполните: scripts/fetch-runtime.sh $os"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    require_cmd curl unzip tar
    case "${1:-}" in
        linux | windows) fetch_os "$1" ;;
        all) fetch_os linux && fetch_os windows ;;
        *) die "использование: scripts/fetch-runtime.sh linux|windows|all" ;;
    esac
fi
