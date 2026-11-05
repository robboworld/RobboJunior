#!/bin/bash
# Общие функции для скриптов сборки RobboJunior. Подключать: source "$(dirname "$0")/lib/common.sh"

# Корень монорепозитория (каталог с CHANGELOG.md)
RJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RJ_DESKTOP="$RJ_ROOT/desktop"
RJ_ANDROID="$RJ_ROOT/android"
RJ_PACKAGING="$RJ_ROOT/packaging"
RJ_RUNTIME="${RJ_RUNTIME_DIR:-$RJ_ROOT/runtime}"

# Имя пакета/продукта: одно на все платформы (deb Package:, rpm Name:, имя exe-установщика)
RJ_PACKAGE_NAME="robboJunior"
RJ_DISPLAY_NAME="Robbo Junior"
RJ_INSTALL_DIR_LINUX="/opt/robboJunior"

die() {
    echo "Ошибка: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

require_cmd() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "не найдена команда '$cmd'. Установите её (см. README.md, раздел «Требования»)."
    done
}

# Файл не меньше заданного размера в байтах — защита от пустых/битых артефактов
require_min_size() {
    local file="$1" min="$2" size
    [ -f "$file" ] || die "нет файла $file"
    size=$(wc -c <"$file" | tr -d ' ')
    [ "$size" -ge "$min" ] || die "файл $file подозрительно мал ($size байт, ожидалось ≥ $min)"
}

# config/local.conf — необязательные локальные настройки (пути, ключи). Переменные окружения важнее.
load_local_config() {
    local conf="$RJ_ROOT/config/local.conf"
    if [ -f "$conf" ]; then
        # shellcheck disable=SC1090
        source "$conf"
    fi
}

# sha256 файла (Linux: sha256sum, macOS: shasum)
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}
