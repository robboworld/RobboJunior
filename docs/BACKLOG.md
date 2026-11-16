# Backlog

Отложенные задачи, которые не входят в текущую разработку. Формат: что, почему отложено, с чего начать.

## Зеркала

### Удалить старые сборки из old_releases на files.robbo.ru

- **Что:** удалить из `Software/RobboJunior/old_releases/` экспериментальные сборки и версии 2017–2018 годов, около 3,8 ГБ. Оставить 0.0.10, 0.0.12 (обе x32 и x64) и 0.0.18: это последние сборки 2019 года и предыдущая стабильная версия перед 0.0.23, на неё можно откатиться.
- **Удалить, экспериментальные сборки (около 2,3 ГБ), они не выходили как версии:**
  - `Linux/robbojunior0.0.10-x64-nwjs.deb`, `Linux/robbojunior0.0.12-x64-nwjs.deb`, `Linux/robbojunior0.0.14-x64-nwjs.deb`
  - `Linux/robbojunior0.0.13-no-scale-x32.deb`, `Linux/robbojunior0.0.13-no-scale-x64.deb`
  - `Linux/robbojunior0.0.15-x64.deb`
  - `Windows/robbojunior-0.0.11-x32.exe`, `Windows/robbojunior-0.0.11-x64.exe`
  - `Windows/robbojunior-0.0.12-dev-x32.exe`, `Windows/robbojunior-0.0.12-dev-x64.exe`
  - `Windows/robbojunior-0.0.12-without-drivers-x32.exe`, `Windows/robbojunior-0.0.12-without-drivers-x64.exe`
  - `Windows/robbojunior-0.0.13-no-scale-x32.exe`, `Windows/robbojunior-0.0.13-no-scale-x64.exe`
- **Удалить, версии 2017–2018 (около 1,5 ГБ):**
  - `Windows/robbojunior-0.0.2-x32.exe`, `Windows/robbojunior-0.0.2-x64.exe`
  - `Linux/robbojunior0.0.4-x32.deb`, `Linux/robbojunior0.0.4-x64.deb`
  - `Linux/robbojunior0.0.9-x32.deb`, `Linux/robbojunior0.0.9-x64.deb`, `Windows/robbojunior-0.0.9-x32.exe`, `Windows/robbojunior-0.0.9-x64.exe`
  - `Rasberry_pi/robbojunior0.0.9-armhf.deb`, `Mac/RobboJunior.app.zip` (2017); после них пустые `Mac/` и `Rasberry_pi/` убрать. Текущие Mac 0.0.10 и Raspberry Pi 0.0.18 лежат в `release/`.
- **Состояние (2026-11-16):** список согласован, удаление отложено по решению руководителя. Перед этим на files.robbo.ru навели порядок: в корне только `release/`, `alpha/`, `old_releases/`, сборки из `unstable/` разложены по `old_releases/Linux` и `old_releases/Windows`, дубли 0.0.18 удалены после сверки MD5.
- **Почему отложено:** удаление необратимо. Нужно убедиться, что школы не ставят 0.0.9 или 0.0.12 по старым инструкциям.
- **С чего начать:** проверить, нет ли ссылок на эти файлы в инструкциях и на сайте. Затем удалить по SFTP поимённо (`rm` без рекурсии, доступ — `config/deploy.conf`) и проверить по HTTP, что `release/` и оставленные версии скачиваются. На files.robbo.world каталога `old_releases/` нет.
