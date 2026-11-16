#!/bin/bash
# Лаунчер Robbo Junior (ставится в /opt/robboJunior/robboJunior).
# Запускает Java-панель управления роботом; панель сама открывает окно Junior (jr/junior)
# и завершается, когда окно закрывают.

INSTALL_DIR="/opt/robboJunior"

# Уже открыт — второй экземпляр не запускаем (панель всё равно не сможет занять порт 9876)
if pgrep -u "$(id -u)" -f "jr/junior" >/dev/null 2>&1; then
    exit 0
fi

# Для работы с роботом по USB нужен доступ к /dev/ttyUSB* — группа dialout
if [ "$(id -u)" -ne 0 ] && ! id -nG "$USER" | grep -qw dialout; then
    text="Чтобы Robbo Junior видел робота по USB, пользователя '$USER' нужно добавить в группу dialout:\n\nsudo usermod -a -G dialout $USER\n\nи затем выйти из системы и войти снова."
    if command -v zenity >/dev/null 2>&1; then
        zenity --warning --no-wrap --text "$text" 2>/dev/null || true
    else
        echo -e "$text" >&2
    fi
fi

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/robboJunior"
mkdir -p "$LOG_DIR"

# Панель запускает GUI по относительному пути ./jr/junior — рабочий каталог обязателен
cd "$INSTALL_DIR" || exit 1

# Журнал: panel.log (предыдущий запуск — panel.old.log). Окно Junior пишет рядом свой журнал
# в ~/.config/RobboJunior/logs/main.log. Заголовок нужен, чтобы по одному файлу было видно окружение.
[ -f "$LOG_DIR/panel.log" ] && mv -f "$LOG_DIR/panel.log" "$LOG_DIR/panel.old.log"
{
    echo "$(date '+%F %T') start robboJunior"
    uname -a
    echo "DISPLAY=${DISPLAY:-} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-} XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-} LANG=${LANG:-}"
    "$INSTALL_DIR/java/bin/java" -version 2>&1
} >"$LOG_DIR/panel.log" 2>&1

exec "$INSTALL_DIR/java/bin/java" -Xmx256m -cp "$INSTALL_DIR/lib/*" scratchduino.robot.Main \
    >>"$LOG_DIR/panel.log" 2>&1
