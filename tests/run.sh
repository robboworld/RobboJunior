#!/bin/bash
# Проверки Robbo Junior, описание в tests/README.md.
#
#   tests/run.sh [--app <каталог>] [--only <часть названия>]
#   tests/run.sh --profile <каталог> --old-home <домашний каталог, где создан профиль>
#
#   --app   проверить не desktop/, а другой каталог приложения, например jr/resources/app из stage-app.sh
#   --only  запустить только сценарии с этой частью названия
#   --profile  открыть все проекты из копии старого профиля: в каталоге лежат RobboJunior и RobboJuniorProjects
#
# Нужны собранный бандл (scripts/build.sh), xvfb-run и свободный порт 9876.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib/common.sh"

APP_DIR="$RJ_DESKTOP"
ONLY=""
PROFILE=""
OLD_HOME=""
while [ $# -gt 0 ]; do
    case "$1" in
        --app) APP_DIR=$(cd "${2:?}" && pwd); shift 2 ;;
        --only) ONLY="${2:?}"; shift 2 ;;
        --profile) PROFILE=$(cd "${2:?}" && pwd); shift 2 ;;
        --old-home) OLD_HOME="${2:?}"; shift 2 ;;
        -h | --help) sed -n '2,11p' "$0"; exit 0 ;;
        *) die "неизвестный аргумент '$1' (см. --help)" ;;
    esac
done
require_cmd node xvfb-run python3
[ -f "$APP_DIR/app.bundle.js" ] || die "нет $APP_DIR/app.bundle.js (сначала scripts/build.sh)"
[ -x "$RJ_DESKTOP/node_modules/electron/dist/electron" ] || die "нет Electron в desktop/node_modules (сначала scripts/build.sh)"
if (exec 3<>/dev/tcp/127.0.0.1/9876) 2>/dev/null; then
    die "порт 9876 занят: закройте Robbo Junior или Robbo Scratch"
fi

TESTS="$RJ_ROOT/tests"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/out"

if [ -n "$PROFILE" ]; then
    [ -n "$OLD_HOME" ] || die "для --profile нужен --old-home"
    mkdir -p "$WORK/home/.config"
    cp -R "$PROFILE/RobboJunior" "$PROFILE/RobboJuniorProjects" "$WORK/home/.config/"
    python3 "$RJ_ROOT/tests/move-profile.py" "$WORK/home/.config/RobboJunior" "$OLD_HOME" "$WORK/home"
    ONLY="старый профиль"
fi

info "Проверка переводов"
node "$TESTS/check-locales.js" "$APP_DIR"

info "Логика робота"
node "$TESTS/robot-logic.js" "$RJ_DESKTOP/src/editor/engine/Robot.js"

run_scenarios() {
    local home="$1" only="$2" profile="$3"
    HOME="$home" RJ_APP_DIR="$APP_DIR" RJ_TEST_OUT="$WORK/out" RJ_TEST_ONLY="$only" RJ_TEST_PROFILE="$profile" \
        RJ_TEST_FIXTURES="$TESTS/fixtures" \
        timeout 180 xvfb-run -a -s '-screen 0 1280x800x24' \
        "$RJ_DESKTOP/node_modules/electron/dist/electron" --no-sandbox --lang=ru "$TESTS/smoke" 2>/dev/null \
        | grep -aE '^(\[ OK \]|\[FAIL\]| +открыто|Провалено|Все сценарии)' || status=1
    [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
}

info "Сценарии в приложении ($APP_DIR)"
status=0
run_scenarios "$WORK/home" "$ONLY" "$PROFILE"

# Профиль из настоящей 0.0.23: каждый запуск проверяет, что старые проекты открываются
if [ -z "$PROFILE" ] && [ -z "$ONLY" ]; then
    info "Профиль 0.0.23"
    mkdir -p "$WORK/home-old/.config"
    tar -xzf "$TESTS/fixtures/profile-0.0.23.tar.gz" -C "$WORK/home-old/.config"
    python3 "$TESTS/move-profile.py" "$WORK/home-old/.config/RobboJunior" "$(cat "$TESTS/fixtures/profile-0.0.23.home")" "$WORK/home-old"
    run_scenarios "$WORK/home-old" "старый профиль" "fixture"
fi

if [ "$status" -ne 0 ]; then
    rm -rf "$RJ_ROOT/.build-logs/tests"
    mkdir -p "$RJ_ROOT/.build-logs/tests"
    cp "$WORK"/out/fail-*.png "$RJ_ROOT/.build-logs/tests/" 2>/dev/null || true
    die "есть провалы, снимки экрана: .build-logs/tests/"
fi
info "Готово"
