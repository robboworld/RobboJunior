; Robbo Junior — установщик Windows x64 (Modern UI 2, русский и английский).
; Собирается на Linux скриптом build_windows.sh (makensis), не вручную:
;   makensis -DSTAGE_DIR=<раскладка stage-app.sh> -DDRIVERS_DIR=... -DICON_FILE=... -DOUT_FILE=... RobboJunior.nsi
; ВАЖНО: файл в UTF-8 с BOM, иначе кириллица в окнах установщика ломается.
Unicode True

!ifndef STAGE_DIR
  !error "Не задан STAGE_DIR. Собирайте через packaging/windows/build_windows.sh"
!endif
!ifndef ROBBO_COMPRESSOR
  !define ROBBO_COMPRESSOR zlib
!endif
!if "${ROBBO_COMPRESSOR}" == "lzma"
  SetCompressor /SOLID lzma
  SetCompressorDictSize 64
!else
  SetCompressor zlib
!endif

!if ! /FileExists "${STAGE_DIR}\jr\junior.exe"
  !error "В STAGE_DIR нет jr\junior.exe — сначала scripts/stage-app.sh windows"
!endif
!if ! /FileExists "${DRIVERS_DIR}\ftdi_cdm\ftdibus.inf"
  !error "В DRIVERS_DIR нет ftdi_cdm\ftdibus.inf"
!endif

!include LogicLib.nsh
!include x64.nsh
!include MUI2.nsh

!define VERSION "1.0.0-alpha"
!define PRODUCT_NAME "Robbo Junior"
!define REG_KEY "robboJunior"
; Ярлык запускает Java-панель; она сама открывает окно Junior (jr\junior.exe)
; относительно рабочего каталога — поэтому у ярлыка рабочий каталог $INSTDIR.
!define PANEL_EXE "$INSTDIR\java\bin\javaw.exe"
!define PANEL_ARGS '-Xmx256m -cp "lib\*" scratchduino.robot.Main'

Name "${PRODUCT_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\robboJunior"
RequestExecutionLevel admin
BrandingText "${PRODUCT_NAME} ${VERSION}"

!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "English"

LangString SEC_MAIN_DESC ${LANG_RUSSIAN} "Программа Robbo Junior, Java-панель управления роботом и встроенная Java 8"
LangString SEC_MAIN_DESC ${LANG_ENGLISH} "Robbo Junior application, robot control panel and bundled Java 8"
LangString SEC_ROBBO_DESC ${LANG_RUSSIAN} "Драйвер FTDI для Робоплатформы и Лаборатории"
LangString SEC_ROBBO_DESC ${LANG_ENGLISH} "FTDI driver for Robot platform and Laboratory"
LangString SEC_ARDUINO_DESC ${LANG_RUSSIAN} "Драйверы Scratchduino/Arduino"
LangString SEC_ARDUINO_DESC ${LANG_ENGLISH} "Scratchduino/Arduino drivers"
LangString SEC_CH340_DESC ${LANG_RUSSIAN} "Драйвер USB-UART CH340"
LangString SEC_CH340_DESC ${LANG_ENGLISH} "CH340 USB-to-serial driver"
LangString SEC_SHORTCUTS_DESC ${LANG_RUSSIAN} "Ярлыки в меню «Пуск» и на рабочем столе"
LangString SEC_SHORTCUTS_DESC ${LANG_ENGLISH} "Start Menu and Desktop shortcuts"
LangString SEC_DRIVERS ${LANG_RUSSIAN} "Драйверы"
LangString SEC_DRIVERS ${LANG_ENGLISH} "Drivers"
LangString SEC_SHORTCUTS ${LANG_RUSSIAN} "Ярлыки"
LangString SEC_SHORTCUTS ${LANG_ENGLISH} "Shortcuts"
LangString DRIVER_WARN ${LANG_RUSSIAN} "Не все драйверы установились — робот может не определяться.$\n$\nДрайверы лежат в $INSTDIR\drivers, журнал — $INSTDIR\drivers\install-drivers.log"
LangString DRIVER_WARN ${LANG_ENGLISH} "Not all drivers were installed — the robot may not be detected.$\n$\nDrivers: $INSTDIR\drivers, log: $INSTDIR\drivers\install-drivers.log"
LangString NOT_64BIT ${LANG_RUSSIAN} "Robbo Junior работает только на 64-битной Windows."
LangString NOT_64BIT ${LANG_ENGLISH} "Robbo Junior requires 64-bit Windows."
LangString INCOMPLETE ${LANG_RUSSIAN} "Установка неполная: нет файлов программы.$\n$\nСкопируйте установщик на локальный диск и запустите снова."
LangString INCOMPLETE ${LANG_ENGLISH} "Installation incomplete: application files are missing.$\n$\nCopy the installer to a local disk and run it again."

Var DriverFailed

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "$(NOT_64BIT)"
    Abort
  ${EndIf}
  SetRegView 64
  StrCpy $DriverFailed "0"
FunctionEnd

Function un.onInit
  SetRegView 64
FunctionEnd

; Запуск драйвера с учётом кода выхода. Стек: команда
Function ExecDriver
  Exch $0
  DetailPrint "$0"
  ExecWait $0 $1
  ${If} $1 != 0
    DetailPrint "  код выхода $1"
    StrCpy $DriverFailed "1"
  ${EndIf}
  Pop $0
FunctionEnd

Function .onInstSuccess
  ${If} $DriverFailed == "1"
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(DRIVER_WARN)"
  ${EndIf}
FunctionEnd

; Закрыть запущенный Junior и панель, иначе файлы заняты
!macro CloseRunning
  nsExec::Exec 'taskkill /F /IM junior.exe'
  Pop $0
  ; Java-панель — только наша (по пути), чужие java.exe не трогаем; $$ — буквальный $ в NSIS
  nsExec::Exec `powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $$_.ExecutablePath -like '*\robboJunior\java\bin\java*' } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force }"`
  Pop $0
!macroend

Section "!${PRODUCT_NAME}" SecMain
  SectionIn RO
  !insertmacro CloseRunning

  ; Чистая установка поверх прошлой версии: старые файлы GUI/runtime не должны смешиваться
  RMDir /r "$INSTDIR\jr"
  RMDir /r "$INSTDIR\java"
  RMDir /r "$INSTDIR\lib"

  SetOutPath "$INSTDIR"
  File /r "${STAGE_DIR}\*.*"
  File "/oname=robbojunior.ico" "${ICON_FILE}"

  ${IfNot} ${FileExists} "$INSTDIR\jr\junior.exe"
  ${OrIfNot} ${FileExists} "$INSTDIR\jr\resources\app\app.bundle.js"
  ${OrIfNot} ${FileExists} "$INSTDIR\java\bin\javaw.exe"
  ${OrIfNot} ${FileExists} "$INSTDIR\lib\i-robot.jar"
    MessageBox MB_ICONSTOP "$(INCOMPLETE)"
    Abort
  ${EndIf}

  SetOutPath "$INSTDIR\drivers"
  File /r "${DRIVERS_DIR}\*.*"

  ; Панель слушает 0.0.0.0:9876/9877. Локальным подключениям firewall не мешает,
  ; а снаружи управлять роботом незачем: запрещаем входящие — и Windows не спрашивает про доступ.
  nsExec::Exec 'netsh advfirewall firewall delete rule name="robboJunior"'
  Pop $0
  nsExec::Exec 'netsh advfirewall firewall add rule name="robboJunior" dir=in action=block program="$INSTDIR\java\bin\javaw.exe" enable=yes'
  Pop $0
  nsExec::Exec 'netsh advfirewall firewall add rule name="robboJunior" dir=in action=block program="$INSTDIR\java\bin\java.exe" enable=yes'
  Pop $0

  WriteRegStr HKLM "SOFTWARE\${REG_KEY}" "Install_Dir" "$INSTDIR"
  WriteRegStr HKLM "SOFTWARE\${REG_KEY}" "Version" "${VERSION}"
  !define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${REG_KEY}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "ROBBO"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\robbojunior.ico"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

SectionGroup "$(SEC_DRIVERS)" SecDrivers
  Section "FTDI (Robbo)" SecRobboDrivers
    Push '"$INSTDIR\drivers\install_ftdi_cdm.cmd"'
    Call ExecDriver
  SectionEnd
  Section "Scratchduino/Arduino" SecArduinoDrivers
    Push '"$INSTDIR\drivers\scratchduino_drivers\install_arduino_drivers.cmd"'
    Call ExecDriver
  SectionEnd
  Section "CH340" SecCH340Drivers
    Push '"$INSTDIR\drivers\CH340SER.EXE" /S'
    Call ExecDriver
  SectionEnd
SectionGroupEnd

Section "$(SEC_SHORTCUTS)" SecShortcuts
  SetShellVarContext all
  ; Рабочий каталог ярлыка = текущий SetOutPath
  SetOutPath "$INSTDIR"
  CreateDirectory "$SMPROGRAMS\Robbo"
  CreateShortcut "$SMPROGRAMS\Robbo\${PRODUCT_NAME}.lnk" "${PANEL_EXE}" '${PANEL_ARGS}' "$INSTDIR\robbojunior.ico" 0
  CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" "${PANEL_EXE}" '${PANEL_ARGS}' "$INSTDIR\robbojunior.ico" 0
  CreateShortcut "$SMPROGRAMS\Robbo\${PRODUCT_NAME} — удалить.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\robbojunior.ico" 0
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "$(SEC_MAIN_DESC)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecRobboDrivers} "$(SEC_ROBBO_DESC)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecArduinoDrivers} "$(SEC_ARDUINO_DESC)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecCH340Drivers} "$(SEC_CH340_DESC)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecShortcuts} "$(SEC_SHORTCUTS_DESC)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SetShellVarContext all
  !insertmacro CloseRunning
  nsExec::Exec 'netsh advfirewall firewall delete rule name="robboJunior"'
  Pop $0

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${REG_KEY}"
  DeleteRegKey HKLM "SOFTWARE\${REG_KEY}"

  RMDir /r "$INSTDIR\jr"
  RMDir /r "$INSTDIR\java"
  RMDir /r "$INSTDIR\lib"
  RMDir /r "$INSTDIR\firmware"
  RMDir /r "$INSTDIR\drivers"
  Delete "$INSTDIR\config.ini"
  Delete "$INSTDIR\i18n.*"
  Delete "$INSTDIR\runtime-version.txt"
  Delete "$INSTDIR\robbojunior.ico"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\Robbo\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\Robbo\${PRODUCT_NAME} — удалить.lnk"
  RMDir "$SMPROGRAMS\Robbo"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  ; Проекты детей (AppData\Local\RobboJuniorProjects) не удаляем
SectionEnd
