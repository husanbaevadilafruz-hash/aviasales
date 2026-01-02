# Скрипт для запуска Flutter приложения на Windows
# Использование: .\run_windows.ps1

Write-Host "🚀 Запуск Flutter приложения на Windows..." -ForegroundColor Green

# Переходим в директорию mobile
Set-Location $PSScriptRoot

# Проверяем доступные устройства
Write-Host "`n📱 Проверка доступных устройств..." -ForegroundColor Yellow
flutter devices

Write-Host "`n🪟 Запуск на Windows..." -ForegroundColor Cyan
flutter run -d windows


