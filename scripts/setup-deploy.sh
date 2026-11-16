#!/bin/bash
# Записывает доступы для scripts/deploy.sh: спрашивает хост, порт, пользователя и пароль и создаёт
#   config/deploy.conf         files.robbo.ru    (SFTP)
#   config/deploy.world.conf   files.robbo.world (FTP, TLS)
# Файлы не попадают в git (config/*.conf в .gitignore), права 600. Пароль вводится скрыто и нигде не печатается.
#
#   scripts/setup-deploy.sh [--target ru|world|all] [--force] [--check]
#
#   --target  какой сервер настроить (по умолчанию all)
#   --force   перезаписывать существующие файлы без вопроса
#   --check   ничего не записывать, а проверить уже записанные доступы: войти на сервер и вывести
#             содержимое каталога RobboJunior/ (только чтение, ничего не загружается и не удаляется)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

TARGET="all"
FORCE=0
CHECK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="${2:?}"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --check) CHECK=1; shift ;;
        -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
        *) die "неизвестный аргумент '$1' (см. --help)" ;;
    esac
done
case "$TARGET" in
    ru) TARGETS=(ru) ;;
    world) TARGETS=(world) ;;
    all) TARGETS=(ru world) ;;
    *) die "неизвестная цель '$TARGET' (ru, world, all)" ;;
esac

# Пути на серверах те же, что в scripts/deploy.sh (deploy_target): менять в обоих местах
conf_of() { case "$1" in ru) echo "$RJ_ROOT/config/deploy.conf" ;; world) echo "$RJ_ROOT/config/deploy.world.conf" ;; esac; }
remote_of() {
    case "$1" in
        ru) echo "/home/ftp/scratchduino/ftp/Software/RobboJunior/" ;;
        world) echo "/files.robbo.world/public_html/Software/RobboJunior/" ;;
    esac
}

ask() { # ask <переменная> <вопрос> [значение по умолчанию]
    local reply
    read -r -p "$2${3:+ [$3]}: " reply
    printf -v "$1" '%s' "${reply:-${3:-}}"
}

ask_yes_no() { # ask_yes_no <вопрос> <y|n по умолчанию>; код 0 = да
    local reply default="$2"
    read -r -p "$1 [$([ "$default" = y ] && echo Y/n || echo y/N)] " reply
    reply="${reply:-$default}"
    case "$reply" in y | Y | д | Д) return 0 ;; *) return 1 ;; esac
}

ask_secret() { # ask_secret <переменная>: пароль без эха, с повтором
    local first second
    while :; do
        read -r -s -p "Пароль: " first
        echo
        if [ -z "$first" ]; then
            echo "Пароль не может быть пустым."
            continue
        fi
        read -r -s -p "Повторите пароль: " second
        echo
        [ "$first" = "$second" ] && break
        echo "Пароли не совпали."
    done
    printf -v "$1" '%s' "$first"
}

write_conf() {
    local target="$1" file host port user pass transport ssl=1 ssl_verify=0 tmp
    file=$(conf_of "$target")
    if [ -e "$file" ] && [ "$FORCE" -eq 0 ]; then
        ask_yes_no "$file уже есть. Перезаписать?" n || { info "$target: оставляю как есть"; return 0; }
    fi

    case "$target" in
        ru)
            info "files.robbo.ru: SFTP"
            transport="sftp"
            ask host "Хост" "files.robbo.ru"
            ask port "Порт" "22"
            ;;
        world)
            info "files.robbo.world: FTP"
            transport="ftp"
            ask host "Хост" "files.robbo.world"
            ask port "Порт" "21"
            ;;
    esac
    ask user "Пользователь"
    [ -n "$user" ] || die "пользователь не указан"
    ask_secret pass
    if [ "$transport" = "ftp" ]; then
        ask_yes_no "Шифровать соединение (FTP поверх TLS)?" y && ssl=1 || ssl=0
        if [ "$ssl" = 1 ]; then
            ask_yes_no "Проверять сертификат сервера? (в шаблоне выключено)" n && ssl_verify=1 || ssl_verify=0
        fi
    fi

    mkdir -p "$(dirname "$file")"
    # Временный файл создаётся с правами 600 и переименовывается: пароль не лежит открытым ни секунды
    tmp=$(mktemp "$file.XXXXXX")
    chmod 600 "$tmp"
    {
        echo "# Выкладка на $host ($(echo "$transport" | tr a-z A-Z)). Создано scripts/setup-deploy.sh $(date '+%F %T')."
        echo "# config/*.conf не попадает в git: не коммитьте пароли."
        printf 'DEPLOY_TRANSPORT=%q\n' "$transport"
        printf 'DEPLOY_HOST=%q\n' "$host"
        printf 'DEPLOY_PORT=%q\n' "$port"
        printf 'DEPLOY_USER=%q\n' "$user"
        printf 'DEPLOY_PASS=%q\n' "$pass"
        if [ "$transport" = "ftp" ]; then
            printf 'DEPLOY_FTP_SSL=%q\n' "$ssl"
            printf 'DEPLOY_FTP_SSL_VERIFY=%q\n' "$ssl_verify"
        fi
    } >"$tmp"
    mv -f "$tmp" "$file"
    info "$target: записано в $file (права 600)"

    # Файл с паролем не должен попасть в git. Код 1 — путь не игнорируется; остальные (не репозиторий) не важны
    local rc=0
    git -C "$RJ_ROOT" check-ignore -q "$file" 2>/dev/null || rc=$?
    [ "$rc" -ne 1 ] || echo "ВНИМАНИЕ: $file не игнорируется git, не добавляйте его в коммит." >&2
}

# Только чтение: вход и список каталога. Пароль уходит в lftp через временный файл с правами 600
check_conf() {
    local target="$1" file remote script
    file=$(conf_of "$target")
    [ -f "$file" ] || { echo "$target: нет $file (сначала scripts/setup-deploy.sh --target $target)" >&2; return 1; }
    require_cmd lftp
    local DEPLOY_TRANSPORT="" DEPLOY_HOST="" DEPLOY_USER="" DEPLOY_PASS="" DEPLOY_PORT=""
    local DEPLOY_FTP_SSL=0 DEPLOY_FTP_SSL_VERIFY=0
    # shellcheck disable=SC1090
    source "$file"
    : "${DEPLOY_HOST:?нет DEPLOY_HOST в $file}"
    remote=$(remote_of "$target")
    script=$(mktemp)
    chmod 600 "$script"
    trap 'rm -f "$script"' RETURN
    {
        echo "set net:timeout 30"
        echo "set net:max-retries 1"
        if [ "${DEPLOY_TRANSPORT:-ftp}" = "sftp" ]; then
            echo "set sftp:auto-confirm yes"
            # files.robbo.ru предлагает только старые ключи (так же в scripts/deploy.sh)
            echo "set sftp:connect-program \"ssh -a -x -p ${DEPLOY_PORT:-22} -o StrictHostKeyChecking=accept-new -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa\""
        elif [ "${DEPLOY_FTP_SSL:-0}" != "0" ]; then
            echo "set ftp:ssl-allow yes"
            echo "set ftp:ssl-protect-data true"
            [ "${DEPLOY_FTP_SSL_VERIFY:-0}" != "0" ] && echo "set ssl:verify-certificate yes" || echo "set ssl:verify-certificate no"
        else
            echo "set ftp:ssl-allow no"
        fi
        echo "open -u \"$DEPLOY_USER\",\"$DEPLOY_PASS\" -p ${DEPLOY_PORT:-21} ${DEPLOY_TRANSPORT:-ftp}://$DEPLOY_HOST"
        echo "cls -1 $remote"
        echo "bye"
    } >"$script"
    info "$target: вход на $DEPLOY_HOST, каталог $remote"
    lftp -f "$script" 2>&1 | sed -u -E 's#(://[^:/@]*):[^/]*@#\1:***@#g'
    [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "$target: вход или чтение каталога не удались" >&2; return 1; }
    info "$target: доступы рабочие"
}

[ -t 0 ] || [ "$CHECK" -eq 1 ] || echo "Скрипт читает ответы со стандартного ввода (не терминал): пароль не будет скрыт." >&2

status=0
for t in "${TARGETS[@]}"; do
    if [ "$CHECK" -eq 1 ]; then
        check_conf "$t" || status=1
    else
        write_conf "$t"
    fi
done

if [ "$CHECK" -eq 0 ]; then
    echo
    echo "Что ещё нужно для выкладки:"
    command -v lftp >/dev/null 2>&1 && echo "  lftp: есть" || echo "  lftp: нет (sudo apt install lftp)"
    command -v rpmbuild >/dev/null 2>&1 && echo "  rpmbuild: есть" || echo "  rpmbuild: нет, без него не собрать rpm (sudo apt install rpm)"
    echo "Дальше:"
    echo "  scripts/setup-deploy.sh --check              проверить доступы (только чтение)"
    echo "  scripts/release.sh                           собрать пакеты"
    echo "  scripts/deploy.sh --target <ru|world> --dry-run   план выкладки"
fi
exit "$status"
