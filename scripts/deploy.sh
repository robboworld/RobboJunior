#!/bin/bash
# Выкладка готовых пакетов Robbo Junior на зеркала. Канал — по версии: X.Y.Z-alpha, -beta, -rc.1 идут
# в alpha/, X.Y.Z и X.Y.Z-N в release/.
#
#   scripts/deploy.sh [--target ru|world|all] [--dry-run]
#
# Настройки: config/deploy.conf (ru) и config/deploy.world.conf (world), шаблоны — *.conf.example.
# Пакеты собирает scripts/release.sh. Текущая версия на сервере не трогается.
# Последним загружается latest.json канала: по нему программа предлагает обновиться.
# release: RobboJunior/latest.json, пакеты в release/; alpha: всё в alpha/.

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
case "$(rj_version_suffix "$VERSION")" in
    "" | [0-9]*) CHANNEL=release; PACKAGES_DIR=release; LATEST_REMOTE="" ;;
    *) CHANNEL=alpha; PACKAGES_DIR=alpha; LATEST_REMOTE=alpha/ ;;
esac
FILES=(
    "$RJ_PACKAGING/linux/output/${RJ_PACKAGE_NAME}_$(rj_deb_version "$VERSION")_amd64.deb"
    "$RJ_PACKAGING/linux/output/$RJ_PACKAGE_NAME-$(rj_rpm_version "$VERSION")-$(rj_rpm_release "$VERSION").x86_64.rpm"
    "$RJ_PACKAGING/windows/output/$RJ_PACKAGE_NAME-$VERSION-x64.exe"
    "$RJ_ROOT/CHANGELOG.md"
)
for f in "${FILES[@]}"; do
    [ -f "$f" ] || die "нет файла $f (сначала scripts/release.sh)"
done

# latest.txt — тот же файл: не все веб-серверы отдают .json
DATE=$(sed -nE "s/^## \[$VERSION\] - (.*)\$/\1/p" "$RJ_ROOT/CHANGELOG.md" | head -1)
[ -n "$DATE" ] || die "в CHANGELOG.md нет даты версии $VERSION"
LATEST_DIR=$(mktemp -d)
trap 'rm -rf "$LATEST_DIR"' EXIT
python3 "$RJ_ROOT/scripts/lib/latest-json.py" "$CHANNEL" "$VERSION" "$DATE" "$LATEST_DIR/latest.json" "${FILES[@]:0:3}"
cp "$LATEST_DIR/latest.json" "$LATEST_DIR/latest.txt"

urlencode() {
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

deploy_target() {
    local target="$1" conf remote url
    case "$target" in
        ru)
            conf="$RJ_ROOT/config/deploy.conf"
            remote="/home/ftp/scratchduino/ftp/Software/RobboJunior/"
            url="http://files.robbo.ru/Software/RobboJunior/"
            ;;
        world)
            conf="$RJ_ROOT/config/deploy.world.conf"
            remote="/files.robbo.world/public_html/Software/RobboJunior/"
            url="http://files.robbo.world/Software/RobboJunior/"
            ;;
    esac
    info "$target: $remote$PACKAGES_DIR ($CHANNEL)"
    for f in "${FILES[@]}"; do
        echo "  $(basename "$f")  $(du -h "$f" | cut -f1)"
    done
    echo "  ${LATEST_REMOTE}latest.json, ${LATEST_REMOTE}latest.txt"
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

    connect_commands() {
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
    }

    run_lftp() {
        # lftp печатает адрес с паролем в ошибках — маскируем
        lftp -f "$script" 2>&1 | sed -u -E 's#(://[^:/@]*):[^/]*@#\1:***@#g'
        [ "${PIPESTATUS[0]}" -eq 0 ] || die "$target: выкладка не удалась"
    }

    local script
    script=$(mktemp -p "$LATEST_DIR")  # там же временный файл с паролем: удалится при любом выходе
    {
        connect_commands
        echo "mkdir -p -f $remote$PACKAGES_DIR"
        echo "cd $remote$PACKAGES_DIR"
        for f in "${FILES[@]}"; do
            echo "put -e \"$f\" -o \"$(basename "$f")\""
        done
    } >"$script"

    run_lftp

    # Сверка по HTTP: файл доступен и размер совпадает
    local name size got
    for f in "${FILES[@]}"; do
        name=$(basename "$f")
        size=$(wc -c <"$f")
        got=$(curl -sSI -m 30 "$url$PACKAGES_DIR/$(urlencode "$name")" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -1)
        [ "$got" = "$size" ] || die "$target: $name на сервере ${got:-нет ответа}, локально $size байт"
        echo "  проверено: $url$PACKAGES_DIR/$(urlencode "$name")"
    done

    # После сверки: программа не должна предлагать версию, пока пакеты не на месте
    {
        connect_commands
        echo "cd $remote$LATEST_REMOTE"
        echo "put -e \"$LATEST_DIR/latest.json\" -o latest.json"
        echo "put -e \"$LATEST_DIR/latest.txt\" -o latest.txt"
    } >"$script"
    run_lftp
    size=$(wc -c <"$LATEST_DIR/latest.txt")
    got=$(curl -sSI -m 30 "$url${LATEST_REMOTE}latest.txt" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -1)
    [ "$got" = "$size" ] || die "$target: latest.txt на сервере ${got:-нет ответа}, локально $size байт"
    echo "  проверено: $url${LATEST_REMOTE}latest.txt"
}

for t in "${TARGETS[@]}"; do
    deploy_target "$t"
done
[ "$DRY_RUN" -eq 1 ] && info "dry-run: ничего не выложено" || info "Готово, версия $VERSION"
