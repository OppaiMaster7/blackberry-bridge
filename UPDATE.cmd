@echo off
REM BlackBerry Bridge - one-click updater. Downloads the latest version from GitHub
REM and installs it over this folder. Your access code and settings are kept.
title BlackBerry Bridge - Update
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0host-setup\update.ps1"
