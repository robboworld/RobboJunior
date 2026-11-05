# Changelog

Единственный источник версии RobboJunior. Верхний заголовок `## [X.Y.Z]` читает `scripts/sync-version.sh`
и переносит версию в приложение, пакеты deb/rpm, установщик Windows и Android.

Формат версии: `X.Y.Z`, `X.Y.Z-alpha` (предварительная), `X.Y.Z-N` (пересборка пакета той же версии).

## [1.0.0-alpha]

### Сборка
- Монорепозиторий: `desktop/` (Electron), `android/`, `packaging/` (deb, rpm, Windows, Android), `scripts/`.
- Пакеты собираются одной командой `scripts/release.sh`, runtime (Electron 17.4.11, Java 8) скачивается с проверкой sha256.
- Java-панель: jSSC 2.6 заменён на 2.9.6 — старый падал в нативном коде на 64-битной Java.
- Отключена проверка обновлений панели (указывала на сервер RobboScratch 2).

### Приложение
- Влита ветка `fs_backend-dev`: Electron 17, хранение проектов в файлах, исправления для Windows,
  перенос проектов между компьютерами.

История версий до 1.0.0 — `docs/changelog-legacy.txt` (последняя — 0.0.18).
