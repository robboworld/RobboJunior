#!/bin/bash
# Кладёт ярлык Robbo Junior на рабочий стол пользователя.
#   create_shortcut.sh [user]   (без аргумента — текущий пользователь)

DESKTOP_FILE="/usr/share/applications/robboJunior.desktop"
user="${1:-$USER}"
[ -n "$user" ] && [ "$user" != "root" ] || exit 0

if [ "$(id -un)" = "$user" ]; then
    dir=$(xdg-user-dir DESKTOP 2>/dev/null)
else
    dir=$(su "$user" -c "xdg-user-dir DESKTOP" 2>/dev/null)
fi
[ -n "$dir" ] && [ -d "$dir" ] || exit 0

cp "$DESKTOP_FILE" "$dir/robboJunior.desktop"
chown "$user": "$dir/robboJunior.desktop" 2>/dev/null || true
chmod 755 "$dir/robboJunior.desktop"
# GNOME: пометить ярлык доверенным, иначе он не запускается двойным щелчком
if command -v gio >/dev/null 2>&1; then
    if [ "$(id -un)" = "$user" ]; then
        gio set "$dir/robboJunior.desktop" metadata::trusted true 2>/dev/null || true
    else
        su "$user" -c "gio set '$dir/robboJunior.desktop' metadata::trusted true" 2>/dev/null || true
    fi
fi
exit 0
