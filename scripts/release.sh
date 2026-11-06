#!/bin/bash
# Сборка всех пакетов Robbo Junior одной командой (на Linux).
#
#   scripts/release.sh [--platforms deb,rpm,windows] [--skip-build] [--sequential] [--dry-run]
#
#   --platforms   какие пакеты собирать (по умолчанию deb,rpm,windows)
#   --skip-build  не пересобирать GUI (взять готовый desktop/app.bundle.js)
#   --sequential  собирать пакеты по очереди (по умолчанию параллельно)
#   --dry-run     только проверить окружение и показать план
#
# Версия — из CHANGELOG.md. Результаты: packaging/linux/output/, packaging/windows/output/.
# Логи: .build-logs/release-<время>/. Выкладка на зеркала — scripts/deploy.sh.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$RJ_ROOT/scripts/lib/version.sh"
load_local_config

PLATFORMS="deb,rpm,windows"
SKIP_BUILD=0
SEQUENTIAL=0
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --platforms) PLATFORMS="${2:?}"; shift 2 ;;
        --platforms=*) PLATFORMS="${1#*=}"; shift ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --sequential) SEQUENTIAL=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
        *) die "неизвестный аргумент '$1' (см. --help)" ;;
    esac
done

IFS=',' read -r -a LIST <<<"$PLATFORMS"
NEED_LINUX=0
NEED_WINDOWS=0
for p in "${LIST[@]}"; do
    case "$p" in
        deb) require_cmd dpkg-deb fakeroot; NEED_LINUX=1 ;;
        rpm) require_cmd rpmbuild; NEED_LINUX=1 ;;
        windows) require_cmd makensis; NEED_WINDOWS=1 ;;
        apk) die "apk пока не собирается этим скриптом (см. packaging/android/README.md)" ;;
        *) die "неизвестная платформа '$p' (deb, rpm, windows)" ;;
    esac
done
require_cmd curl unzip tar
[ "$(uname -s)" = "Linux" ] || die "релиз собирается на Linux (dpkg-deb, rpmbuild, makensis)"

VERSION=$(rj_version)
info "Robbo Junior $VERSION: ${LIST[*]}"
info "deb $(rj_deb_version "$VERSION"), rpm $(rj_rpm_version "$VERSION")-$(rj_rpm_release "$VERSION")"

if [ "$DRY_RUN" -eq 1 ]; then
    info "dry-run: окружение в порядке, ничего не собираю"
    exit 0
fi

if [ "$SKIP_BUILD" -eq 0 ]; then
    "$RJ_ROOT/scripts/build.sh"
fi
"$RJ_ROOT/scripts/sync-version.sh"
export RJ_VERSION_SYNC=0
[ "$NEED_LINUX" -eq 1 ] && "$RJ_ROOT/scripts/fetch-runtime.sh" linux
[ "$NEED_WINDOWS" -eq 1 ] && "$RJ_ROOT/scripts/fetch-runtime.sh" windows

LOGS="$RJ_ROOT/.build-logs/release-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOGS"

script_for() {
    case "$1" in
        deb) echo "$RJ_PACKAGING/linux/build_deb.sh" ;;
        rpm) echo "$RJ_PACKAGING/linux/build_rpm.sh" ;;
        windows) echo "$RJ_PACKAGING/windows/build_windows.sh" ;;
    esac
}

declare -A PIDS=()
FAILED=()
for p in "${LIST[@]}"; do
    log="$LOGS/package-$p.log"
    if [ "$p" = "windows" ]; then
        cmd=(env WIN_COMPRESSOR="${WIN_COMPRESSOR:-lzma}" "$(script_for "$p")")
    else
        cmd=("$(script_for "$p")")
    fi
    if [ "$SEQUENTIAL" -eq 1 ]; then
        info "$p…"
        "${cmd[@]}" >"$log" 2>&1 || FAILED+=("$p")
    else
        info "$p запущен (лог: $log)"
        "${cmd[@]}" >"$log" 2>&1 &
        PIDS[$p]=$!
    fi
done
for p in "${!PIDS[@]}"; do
    wait "${PIDS[$p]}" || FAILED+=("$p")
done

for p in "${FAILED[@]}"; do
    echo "---- $p: ошибка, конец лога ----"
    tail -20 "$LOGS/package-$p.log"
done
[ ${#FAILED[@]} -eq 0 ] || die "не собрались: ${FAILED[*]} (логи: $LOGS)"

info "Готово, версия $VERSION:"
ls -lh "$RJ_PACKAGING"/linux/output/*"$(rj_rpm_version "$VERSION")"* \
    "$RJ_PACKAGING"/windows/output/*"$VERSION"* 2>/dev/null || true
