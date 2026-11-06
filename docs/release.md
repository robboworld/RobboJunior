# Выпуск версии Robbo Junior

## Порядок

1. Добавить в начало `CHANGELOG.md` раздел `## [X.Y.Z]` с изменениями.
   - `X.Y.Z-alpha` — предварительная версия (deb `X.Y.Z~alpha`, ставится раньше финальной `X.Y.Z`).
   - `X.Y.Z-N` — пересборка пакета той же версии.
2. На Linux: `scripts/release.sh` (сначала можно `scripts/release.sh --dry-run`).
3. Проверить пакеты (ниже) и закоммитить изменения версии (`scripts/sync-version.sh` правит `desktop/package.json`, `desktop/home.html`, `desktop/version`, deb `control`, rpm spec, `.nsi`).

Результаты:

| Платформа | Файл |
|-----------|------|
| Debian, Ubuntu, Mint, Astra | `packaging/linux/output/robboJunior_<deb-версия>_amd64.deb` |
| Альт, РЕД ОС, Fedora | `packaging/linux/output/robboJunior-<версия>-<релиз>.x86_64.rpm` |
| Windows 10/11 x64 | `packaging/windows/output/robboJunior-<версия>-x64.exe` |

Выкладки на сервер и автообновления пока нет.

## Что проверить перед выпуском

- Установка в чистую систему, ярлык в меню и на рабочем столе.
- Запуск: открывается окно Junior, `curl http://127.0.0.1:9876/` отвечает (панель поднялась).
- Робот по USB выполняет блок движения.
- Закрытие окна завершает панель (`pgrep -f scratchduino` / диспетчер задач — пусто).
- Удаление убирает программу и ярлыки; проекты детей остаются.
- Robbo Scratch и Robbo Junior, установленные вместе, не мешают друг другу.

## Обновление runtime

Версии Electron и Java и их sha256 закреплены в `scripts/fetch-runtime.sh`. После изменения — `scripts/fetch-runtime.sh all` (старый runtime заменится, маркер `runtime-version.txt` обновится).

- Electron: суммы из `SHASUMS256.txt` релиза на GitHub.
- Temurin 8 JRE: `https://api.adoptium.net/v3/assets/latest/8/hotspot?architecture=x64&image_type=jre&os=linux` (и `os=windows`), поле `checksum`.

Java выше 8 не подходит: панель использует JAXB. Внутри Java 8 — не выше 8u402: с 8u412 на Ubuntu 22.04 (GNOME) панель падает при старте в `java.awt.TrayIcon`, окно Junior не открывается.

## Linux: особенности пакетов

- Программа ставится в `/opt/robboJunior`, команда — `robboJunior`.
- `chrome-sandbox` получает setuid при установке — без этого Electron не запускается в Ubuntu 24.04.
- Правило udev `86-robbojunior-ch340.rules` не даёт brltty забирать платы на CH340 (то же, что у Robbo Scratch, но под своим именем — иначе пакеты конфликтуют).
- Для доступа к роботу пользователь должен быть в группе `dialout`; лаунчер подскажет команду.
- Журнал панели: `~/.local/state/robboJunior/panel.log`.

## Windows: особенности установщика

- Ярлык запускает `java\bin\javaw.exe` с рабочим каталогом папки установки — панель ищет `jr\junior.exe` относительно него.
- Входящие подключения к панели из сети запрещены правилом firewall `robboJunior` (локальным это не мешает, и Windows не показывает запрос доступа).
- Галочка «Запустить Robbo Junior» включена по умолчанию. Установщик работает от администратора, поэтому программа запускается через `explorer.exe` и ярлык `robbojunior.lnk` — с правами обычного пользователя. При тихой установке (`/S`) запуска нет.
- Драйверы: FTDI ставится всегда, Scratchduino/Arduino — по галочке (старые роботы). CH340 в установщик не входит.
- Подписи exe нет (как и у Robbo Scratch).
