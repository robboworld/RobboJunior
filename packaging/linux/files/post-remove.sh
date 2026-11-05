#!/bin/bash
# Общие действия после удаления — вызываются из DEBIAN/postrm (remove/purge) и %postun в rpm (0).

if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules 2>/dev/null || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
fi

for home in /home/*; do
    for dir in "$home/Desktop" "$home/Рабочий стол"; do
        rm -f "$dir/robboJunior.desktop" "$dir/junior.desktop" 2>/dev/null || true
    done
done

exit 0
