@echo off
setlocal enableextensions
title BlackBerry Bridge - Update
rem ---------------------------------------------------------------------------
rem  One-click updater. Uses ONLY Windows' own built-in signed tools
rem  (curl.exe, tar.exe, robocopy) to download the latest version as a data zip
rem  and unpack it over this folder. No PowerShell, no downloaded scripts - so
rem  Windows Defender does not flag it. Your access code + settings are kept
rem  (they live in files that aren't part of the download).
rem ---------------------------------------------------------------------------
set "ROOT=%~dp0"
set "SYS=%SystemRoot%\System32"
set "ZIP=%TEMP%\bbbridge_update.zip"
set "EXDIR=%TEMP%\bbbridge_update_x"
set "URL=https://github.com/OppaiMaster7/blackberry-bridge/archive/refs/heads/master.zip"

echo(
echo ==================================================
echo    BlackBerry Bridge - UPDATE
echo ==================================================
echo(
echo Updating: %ROOT%
echo Downloading the latest version from GitHub...
"%SYS%\curl.exe" -sL --fail "%URL%" -o "%ZIP%"
if not exist "%ZIP%" goto :failnet

echo Unpacking...
if exist "%EXDIR%" rmdir /s /q "%EXDIR%"
mkdir "%EXDIR%"
"%SYS%\tar.exe" -xf "%ZIP%" -C "%EXDIR%"
if errorlevel 1 goto :failnet

set "SRC="
for /d %%D in ("%EXDIR%\blackberry-bridge-*") do set "SRC=%%D"
if not defined SRC goto :failnet

echo Installing (your access code and settings are kept)...
"%SYS%\robocopy.exe" "%SRC%" "%ROOT%." /E /IS /IT /NFL /NDL /NJH /NJS /NP >nul
if %errorlevel% GEQ 8 goto :failcopy

del /q "%ZIP%" >nul 2>&1
rmdir /s /q "%EXDIR%" >nul 2>&1
echo(
echo ==================================================
echo    UPDATE DONE.
echo ==================================================
echo(
echo  Now double-click START-BRIDGE again to run the new version.
echo  (On the BlackBerry, close the tab and reopen it so it loads fresh.)
echo(
pause
exit /b 0

:failnet
echo(
echo  [X] Could not download the update. Check the internet connection.
echo(
pause
exit /b 1

:failcopy
echo(
echo  [X] Could not write the files. Close START-BRIDGE if it's running, then retry.
echo(
pause
exit /b 1
