@ECHO OFF
cd /d "%~dp0"
call "%~dp0install_arduino_drivers.cmd"
exit /b %ERRORLEVEL%
