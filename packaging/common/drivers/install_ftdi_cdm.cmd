@echo off
REM FTDI CDM 2.12.36.20 (WHQL, HVCI-compatible) for Laboratory and Robot platform.
REM NSIS is 32-bit: under WOW64 System32 has no pnputil, use Sysnative.
set "LOG=%~dp0install-drivers.log"
cd /d "%~dp0ftdi_cdm"
>> "%LOG%" echo [%DATE% %TIME%] FTDI CDM: pnputil /add-driver
set "PNPUTIL=%SystemRoot%\System32\pnputil.exe"
if exist "%SystemRoot%\Sysnative\pnputil.exe" set "PNPUTIL=%SystemRoot%\Sysnative\pnputil.exe"
set "RC=0"
for %%I in (ftdibus.inf ftdiport.inf) do (
  "%PNPUTIL%" /add-driver "%%I" /install >> "%LOG%" 2>&1
  call :check
)
exit /b %RC%

:check
>> "%LOG%" echo FTDI CDM: exit %ERRORLEVEL%
REM 3010 = installed, reboot required; 259 = no newer driver to apply (already up to date)
if %ERRORLEVEL%==0 exit /b 0
if %ERRORLEVEL%==3010 exit /b 0
if %ERRORLEVEL%==259 exit /b 0
set "RC=%ERRORLEVEL%"
exit /b 0
