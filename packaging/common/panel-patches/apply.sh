#!/bin/bash
# Кладёт патчи панели в packaging/common/panel/lib/i-robot.jar (исходников панели в репозитории нет):
#   - TrayIcons.java   панель не падает там, где нет системного трея;
#   - RobboLog.java    журналы панели в каталоге пользователя, вывод окна Junior в junior.out.log;
#   - PatchPanel.java  правка байткода ControlPanel, Main и ScratchExternalCommand.
# Нужны docker (образ eclipse-temurin:8-jdk), zip и unzip. Повторный запуск безопасен:
# уже пропатченные классы пропускаются, а TrayIcons и RobboLog просто пересобираются.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../panel/lib"
JAR="$LIB/i-robot.jar"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/in" "$W/out"
unzip -q "$JAR" 'scratchduino/robot/ui/v1/ControlPanel.class' 'scratchduino/robot/Main.class' \
    'scratchduino/robot/ScratchExternalCommand.class' -d "$W/in"
# /lib нельзя перекрывать: в нём системный загрузчик
docker run --rm -u "$(id -u):$(id -g)" -v "$HERE":/src:ro -v "$LIB":/rjlib:ro -v "$W":/w eclipse-temurin:8-jdk bash -ec '
  cd /w && mkdir -p tool
  javac -nowarn -cp /rjlib/spring-core-4.1.1.RELEASE.jar -d tool /src/PatchPanel.java
  javac -source 8 -target 8 -nowarn -XDignore.symbol.file -d out /src/TrayIcons.java /src/RobboLog.java
  java -cp tool:/rjlib/spring-core-4.1.1.RELEASE.jar PatchPanel in out
'
(cd "$W/out" && find . -name '*.class' | sed 's#^\./##' | xargs zip -q "$JAR")
echo "готово: $JAR"
