# Скрипт для запуска Flutter приложения на Android
# Использование: .\run_android.ps1

Write-Host "🚀 Запуск Flutter приложения на Android..." -ForegroundColor Green

# Переходим в директорию mobile
Set-Location $PSScriptRoot

# Проверяем доступные устройства
Write-Host "`n📱 Проверка доступных устройств..." -ForegroundColor Yellow
flutter devices

Write-Host "`n📱 Запуск на Android эмуляторе..." -ForegroundColor Cyan
flutter run -d emulator-5554


