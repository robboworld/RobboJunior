#!/bin/bash
# Сборка GUI RobboJunior (Electron): npm-зависимости → webpack → готовый desktop/app.bundle.js
#
#   scripts/build.sh            обычная сборка
#   scripts/build.sh --clean    удалить desktop/node_modules и поставить зависимости заново
#
# Node — версия из .nvmrc (если установлен nvm, переключается автоматически).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

CLEAN=0
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=1 ;;
        *) die "неизвестный аргумент '$arg'" ;;
    esac
done

# nvm — функция оболочки, подключаем, если есть
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    # shellcheck disable=SC1091
    source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    (cd "$RJ_ROOT" && nvm use >/dev/null) || die "nvm не смог переключиться на Node $(cat "$RJ_ROOT/.nvmrc"). Выполните: nvm install"
fi

require_cmd node npm
NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
WANT_MAJOR=$(tr -d '[:space:]' <"$RJ_ROOT/.nvmrc")
[ "$NODE_MAJOR" = "$WANT_MAJOR" ] || die "нужен Node $WANT_MAJOR (сейчас $(node -v)). Установите nvm и выполните 'nvm install' в корне репозитория."

"$RJ_ROOT/scripts/sync-version.sh"

cd "$RJ_DESKTOP"

if [ "$CLEAN" -eq 1 ]; then
    info "Удаляю node_modules"
    rm -rf node_modules
fi

if [ ! -d node_modules ]; then
    info "Устанавливаю зависимости (npm ci)"
    npm ci --no-audit --no-fund
fi

info "Собираю бандл (webpack)"
npm run build

BUNDLE="src/build/bundles/app.bundle.js"
require_min_size "$BUNDLE" 1000000

# Код из fs-backend обращается к модулям Node через эти имена (nodeIntegration: true)
{
    echo 'const node_process = require("process");'
    echo 'const node_os = require("os");'
    echo 'const node_fs = require("fs");'
    cat "$BUNDLE"
} >app.bundle.js
cp "src/build/bundles/app.bundle.js.map" app.bundle.js.map

info "Готово: desktop/app.bundle.js ($(wc -c <app.bundle.js | tr -d ' ') байт)"
info "Запуск для проверки: cd desktop && npx electron ."
