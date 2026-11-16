' Запуск Java-панели Robbo Junior со скрытым окном и журналом:
'   %LOCALAPPDATA%\RobboJuniorLogs\panel.log   (предыдущий запуск — panel.old.log)
' Рабочий каталог — папка установки: панель открывает окно Junior по относительному пути jr\junior.exe.
Option Explicit
Dim sh, fso, dir, logDir, logFile, cmd
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
logDir = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\RobboJuniorLogs"
If Not fso.FolderExists(logDir) Then fso.CreateFolder logDir
logFile = logDir & "\panel.log"
On Error Resume Next
If fso.FileExists(logDir & "\panel.old.log") Then fso.DeleteFile logDir & "\panel.old.log", True
If fso.FileExists(logFile) Then fso.MoveFile logFile, logDir & "\panel.old.log"
On Error GoTo 0
sh.CurrentDirectory = dir
' Заголовок журнала: версия Windows и Java, чтобы по одному файлу было видно окружение
cmd = "cmd /c (echo %DATE% %TIME% start & ver & ""java\bin\java.exe"" -version & " & _
      """java\bin\java.exe"" -Xmx256m -cp ""lib\*"" scratchduino.robot.Main) > """ & logFile & """ 2>&1"
sh.Run cmd, 0, False
