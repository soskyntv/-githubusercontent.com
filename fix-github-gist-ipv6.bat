@echo off
chcp 65001 > nul
title Fix GitHub gist/raw/avatars via IPv6
:: ============================================================
::  Исправляет блокировку githubusercontent.com (gist, raw,
::  avatars) когда провайдер блокирует IPv4-подсеть Fastly
::  185.199.108.0/22, но IPv6 работает.
::  Не изменяет ни один скрипт. Только правит hosts.
::  Запускать ОТ ИМЕНИ АДМИНИСТРАТОРА.
:: ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Требуются права администратора.
    echo     Нажмите правой кнопкой по файлу - "Запуск от имени администратора".
    pause
    exit /b 1
)

set "HOST=%SystemRoot%\System32\drivers\etc\hosts"

echo [1/3] Закрываю опасные/зависшие процессы, держащие hosts...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'gist.githubusercontent.com' -and $_.Name -eq 'powershell.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

echo [2/3] Обновляю hosts (IPv6-записи для githubusercontent)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$h=$env:SystemRoot+'\System32\drivers\etc\hosts';" ^
"$lines=@('2606:50c0:8000::154 gist.githubusercontent.com','2606:50c0:8001::154 gist.githubusercontent.com','2606:50c0:8002::154 gist.githubusercontent.com','2606:50c0:8003::154 gist.githubusercontent.com','2606:50c0:8000::154 raw.githubusercontent.com','2606:50c0:8001::154 raw.githubusercontent.com','2606:50c0:8002::154 raw.githubusercontent.com','2606:50c0:8003::154 raw.githubusercontent.com','2606:50c0:8000::154 avatars.githubusercontent.com','2606:50c0:8001::154 avatars.githubusercontent.com','2606:50c0:8002::154 avatars.githubusercontent.com','2606:50c0:8003::154 avatars.githubusercontent.com');" ^
"foreach($d in @('gist.githubusercontent.com','raw.githubusercontent.com','avatars.githubusercontent.com')){ $new=(Get-Content $h | Where-Object { $t=$_.Trim(); -not ($t -match ('\b'+[regex]::Escape($d)+'\b')) }); $new | Set-Content $h -Encoding ASCII };" ^
"Add-Content -Path $h -Value $lines -Encoding ASCII"

echo [3/3] Очищаю DNS-кэш...
ipconfig /flushdns >nul

echo.
echo [OK] Всё готово! GitHub gist/raw/avatars теперь идут через IPv6.
echo     Проверьте ваш скрипт/браузер.
pause
