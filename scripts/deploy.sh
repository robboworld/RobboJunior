#!/bin/bash
# Выкладка готовых пакетов Robbo Junior на зеркала (канал alpha).
#
#   scripts/deploy.sh [--target ru|world|all] [--dry-run]
#
# Настройки: config/deploy.conf (ru) и config/deploy.world.conf (world), шаблоны — *.conf.example.
# Пакеты собирает scripts/release.sh. Текущая версия на сервере не трогается.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$RJ_ROOT/scripts/lib/version.sh"

TARGET="all"
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="${2:?}"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h | --help) sed -n '2,7p' "$0"; exit 0 ;;
        *) die "неизвестный аргумент '$1' (см. --help)" ;;
    esac
done
case "$TARGET" in
    ru) TARGETS=(ru) ;;
    world) TARGETS=(world) ;;
    all) TARGETS=(ru world) ;;
    *) die "неизвестная цель '$TARGET' (ru, world, all)" ;;
esac
require_cmd lftp curl python3

VERSION=$(rj_version)
FILES=(
    "$RJ_PACKAGING/linux/output/${RJ_PACKAGE_NAME}_$(rj_deb_version "$VERSION")_amd64.deb"
    "$RJ_PACKAGING/linux/output/$RJ_PACKAGE_NAME-$(rj_rpm_version "$VERSION")-$(rj_rpm_release "$VERSION").x86_64.rpm"
    "$RJ_PACKAGING/windows/output/$RJ_PACKAGE_NAME-$VERSION-x64.exe"
    "$RJ_ROOT/CHANGELOG.md"
)
for f in "${FILES[@]}"; do
    [ -f "$f" ] || die "нет файла $f (сначала scripts/release.sh)"
done

urlencode() {
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

deploy_target() {
    local target="$1" conf remote url
    case "$target" in
        ru)
            conf="$RJ_ROOT/config/deploy.conf"
            remote="/home/ftp/scratchduino/ftp/Software/RobboJunior/alpha"
            url="http://files.robbo.ru/Software/RobboJunior/alpha/"
            ;;
        world)
            conf="$RJ_ROOT/config/deploy.world.conf"
            remote="/files.robbo.world/public_html/Software/RobboJunior/alpha"
            url="http://files.robbo.world/Software/RobboJunior/alpha/"
            ;;
    esac
    info "$target: $remote"
    for f in "${FILES[@]}"; do
        echo "  $(basename "$f")  $(du -h "$f" | cut -f1)"
    done
    [ "$DRY_RUN" -eq 0 ] || return 0

    [ -f "$conf" ] || die "нет $conf (шаблон — $conf.example)"
    # REMOTE_* из конфига не используем: пути заданы выше, чужие каталоги не затронуть
    local DEPLOY_TRANSPORT="" DEPLOY_HOST="" DEPLOY_USER="" DEPLOY_PASS="" DEPLOY_PORT=""
    local DEPLOY_FTP_SSL=0 DEPLOY_FTP_SSL_FORCE=0 DEPLOY_FTP_SSL_VERIFY=0
    local LFTP_NET_TIMEOUT=30 LFTP_MAX_RETRIES=3
    # shellcheck disable=SC1090
    source "$conf"
    : "${DEPLOY_HOST:?нет DEPLOY_HOST в $conf}"
    : "${DEPLOY_USER:?нет DEPLOY_USER в $conf}"
    : "${DEPLOY_PASS:?нет DEPLOY_PASS в $conf}"
    local proto="${DEPLOY_TRANSPORT:-ftp}"

    local script
    script=$(mktemp)
    chmod 600 "$script"
    trap 'rm -f "$script"' RETURN
    {
        echo "set net:timeout $LFTP_NET_TIMEOUT"
        echo "set net:max-retries $LFTP_MAX_RETRIES"
        echo "set cmd:fail-exit yes"
        if [ "$proto" = "sftp" ]; then
            echo "set sftp:auto-confirm yes"
            # files.robbo.ru предлагает только старые ключи: ssh-rsa надо разрешить явно
            echo "set sftp:connect-program \"ssh -a -x -p ${DEPLOY_PORT:-22} -o StrictHostKeyChecking=accept-new -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa\""
        elif [ "$DEPLOY_FTP_SSL" != "0" ]; then
            echo "set ftp:ssl-allow yes"
            [ "$DEPLOY_FTP_SSL_FORCE" != "0" ] && echo "set ftp:ssl-force true" || echo "set ftp:ssl-force false"
            echo "set ftp:ssl-protect-data true"
            [ "$DEPLOY_FTP_SSL_VERIFY" != "0" ] && echo "set ssl:verify-certificate yes" || echo "set ssl:verify-certificate no"
        else
            echo "set ftp:ssl-allow no"
        fi
        echo "open $proto://$(urlencode "$DEPLOY_USER"):$(urlencode "$DEPLOY_PASS")@$DEPLOY_HOST${DEPLOY_PORT:+:$DEPLOY_PORT}"
        echo "mkdir -p -f $remote"
        echo "cd $remote"
        for f in "${FILES[@]}"; do
            echo "put -e \"$f\" -o \"$(basename "$f")\""
        done
    } >"$script"

    # lftp печатает адрес с паролем в ошибках — маскируем
    lftp -f "$script" 2>&1 | sed -u -E 's#(://[^:/@]*):[^/]*@#\1:***@#g'
    [ "${PIPESTATUS[0]}" -eq 0 ] || die "$target: выкладка не удалась"

    # Сверка по HTTP: файл доступен и размер совпадает
    local name size got
    for f in "${FILES[@]}"; do
        name=$(basename "$f")
        size=$(wc -c <"$f")
        got=$(curl -sSI -m 30 "$url$(urlencode "$name")" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -1)
        [ "$got" = "$size" ] || die "$target: $name на сервере ${got:-нет ответа}, локально $size байт"
        echo "  проверено: $url$(urlencode "$name")"
    done
}

for t in "${TARGETS[@]}"; do
    deploy_target "$t"
done
[ "$DRY_RUN" -eq 1 ] && info "dry-run: ничего не выложено" || info "Готово, версия $VERSION"
