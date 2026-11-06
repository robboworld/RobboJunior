# Robbo Junior

Среда визуального программирования для детей 5–8 лет с поддержкой роботов Роббо. Форк [ScratchJr](https://github.com/LLK/scratchjr) (MIT Media Lab, Tufts University, Playful Invention Company).

Монорепозиторий: код приложения для компьютера и Android, упаковка под все платформы и релизный скрипт.

## Что где лежит

| Путь | В git | Содержимое |
|------|-------|------------|
| `desktop/` | да | Приложение для компьютера (Electron 17): `src/` — исходники, остальное — ресурсы GUI |
| `android/` | да | Приложение для Android (отдельная кодовая база 2017 года, Android Studio) |
| `packaging/common/panel/` | да | Java-панель управления роботом: jar'ы, `config.ini`, `i18n.*`, прошивки |
| `packaging/common/drivers/` | да | Драйверы Windows (FTDI, Arduino; CH340SER.EXE в установщик не входит) — копия из RS3_Assembly |
| `packaging/common/icons/` | да | Иконки |
| `packaging/linux/` | да | `build_deb.sh`, `build_rpm.sh`, шаблоны пакетов, общие файлы (`files/`) |
| `packaging/windows/` | да | `build_windows.sh`, `RobboJunior.nsi` |
| `scripts/` | да | `build.sh`, `release.sh`, `fetch-runtime.sh`, `stage-app.sh`, `sync-version.sh` |
| `CHANGELOG.md` | да | **Единственный источник версии** |
| `runtime/` | нет | Electron и Java 8 — скачивает `scripts/fetch-runtime.sh` с проверкой sha256 |
| `packaging/*/output/` | нет | Готовые пакеты |
| `config/local.conf` | нет | Локальные настройки (шаблон — `config/local.conf.example`) |

## Как устроено приложение

```
ярлык → Java-панель (java -cp lib/* scratchduino.robot.Main, порт 127.0.0.1:9876)
            └─ запускает jr/junior (Electron) → окно Junior
               Junior шлёт команды роботу HTTP-запросами на 127.0.0.1:9876
            панель завершается, когда окно Junior закрывают
```

- Панель — из Robbo Scratch 2 (исходники: [robboworld/robboscratch2](https://github.com/robboworld/robboscratch2), каталог `java/`). Берём собранные jar'ы как есть.
- Нужна **Java 8**: на Java 11+ панель падает (нет JAXB). В пакеты кладётся Temurin 8.
- Библиотека COM-портов **jSSC 2.9.6** вместо 2.6 из старой сборки: 2.6 и 2.8 падают в нативном коде на 64-битной Java.
- Порт 9876 зашит в панель. Если он занят другой программой (например, MCP-аддоном Blender), управление роботом не работает.

## Требования

Сборка GUI — любая ОС с Node 20 (`.nvmrc`). Пакеты — **только Linux** (как у Robbo Scratch):

```bash
sudo apt install curl unzip python3 fakeroot dpkg-dev rpm nsis
```

Node: [nvm](https://github.com/nvm-sh/nvm), затем `nvm install` в корне репозитория.

## Быстрый старт

Запустить приложение для разработки:

```bash
scripts/build.sh
cd desktop && npx electron .
```

Без Java-панели окно работает, но робот не отвечает.

Собрать все пакеты:

```bash
scripts/release.sh
```

Отдельные пакеты:

```bash
scripts/build.sh && scripts/fetch-runtime.sh linux
packaging/linux/build_deb.sh
packaging/linux/build_rpm.sh
scripts/fetch-runtime.sh windows && packaging/windows/build_windows.sh
```

Подробности — [docs/release.md](docs/release.md).

## Лицензия

BSD 3-Clause, см. [LICENSE](LICENSE).
