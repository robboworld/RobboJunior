@echo off
set "LOG=%~dp0..\install-drivers.log"
cd /d "%~dp0"
>> "%LOG%" echo [%DATE% %TIME%] Arduino: dpinst
REM Import publishers from signed .cat (needed for silent install on Win10/11)
certutil -addstore TrustedPublisher "arduino.cat" >nul 2>&1
certutil -addstore TrustedPublisher "arduino-org.cat" >nul 2>&1
REM FTDI is not installed here: the HVCI-compatible CDM driver comes from the "Robbo drivers" section
if defined ProgramW6432 (
  dpinst-amd64.exe /lm /sw /se /path "%~dp0"
) else (
  dpinst-x86.exe /lm /sw /se /path "%~dp0"
)
set "RC=%ERRORLEVEL%"
>> "%LOG%" echo Arduino: dpinst exit %RC%
REM DPInst exit code is a bit mask: 0x80000000 = failure (a negative number here), 0x40000000 = reboot
REM needed, the low bytes count installed / copied packages. Anything else is a success.
if %RC% LSS 0 exit /b %RC%
exit /b 0
