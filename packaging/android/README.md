# Android — пока не собирается

Код — в `android/` (импорт `robboworld/robbojunior_android` с историей, версия 0.0.3, 2017 год).

Что мешает собрать его скриптом, как остальные пакеты:

- Gradle 3.3 и Android Gradle Plugin 2.3.3, репозиторий jcenter (закрыт), устаревшее `compile` в зависимостях,
  `targetSdkVersion 25` (Android 14 не ставит приложения с targetSdk ниже 23, Google Play требует свежий).
- Шаг svg → png (`android/bin/convert-svg-to-png.py`) использует `pysvg` через `easy_install` — больше не поддерживаются.
- JS-код Android — отдельный старый форк, не тот, что в `desktop/`.

План: обновить Gradle/AGP/targetSdk, заменить svg → png на `rsvg-convert`, добавить `build_apk.sh`
(подпись ключом из `config/android-signing.conf`, вне git) и платформу `apk` в `scripts/release.sh`.
