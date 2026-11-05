#!/bin/bash
# Общие действия после установки — вызываются из DEBIAN/postinst и %post в rpm.

INSTALL_DIR="/opt/robboJunior"

# Песочница Chromium в Electron: без setuid-бита окно не откроется
# (в Ubuntu 24.04 непривилегированные user namespaces ограничены AppArmor)
if [ -f "$INSTALL_DIR/jr/chrome-sandbox" ]; then
    chown root:root "$INSTALL_DIR/jr/chrome-sandbox"
    chmod 4755 "$INSTALL_DIR/jr/chrome-sandbox"
fi

# Правило 86-robbojunior-ch340.rules: brltty не забирает платы на CH340
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules 2>/dev/null || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
fi

# Ярлык на рабочем столе того, кто ставил пакет
if [ -n "${SUDO_USER:-}" ]; then
    "$INSTALL_DIR/create_shortcut.sh" "$SUDO_USER" 2>/dev/null || true
fi

exit 0
