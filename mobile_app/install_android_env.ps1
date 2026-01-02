Write-Host "=== Iniciando Instalación de Entorno Android (Flet/Flutter) ===" -ForegroundColor Cyan

# 1. Install Java (OpenJDK 17)
Write-Host "`n[1/3] Instalando Java OpenJDK 17..." -ForegroundColor Yellow
winget install Microsoft.OpenJDK.17 -e --id Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements

# 2. Install Flutter
Write-Host "`n[2/3] Instalando Flutter SDK..." -ForegroundColor Yellow
winget install Google.Flutter -e --id Google.Flutter --accept-package-agreements --accept-source-agreements

# 3. Install Android Studio
Write-Host "`n[3/3] Instalando Android Studio..." -ForegroundColor Yellow
winget install Google.AndroidStudio -e --id Google.AndroidStudio --accept-package-agreements --accept-source-agreements

Write-Host "`n=== Instalación de Paquetes Completada ===" -ForegroundColor Green
Write-Host "IMPORTANTE:" -ForegroundColor Red
Write-Host "1. Android Studio se ha instalado. Ábrelo manualmente para completar su asistente inicial (instalará el SDK y 'cmdline-tools')."
Write-Host "2. Reinicia tu terminal (o VS Code) para que se reconozcan los nuevos comandos 'flutter' y 'java'."
Write-Host "3. Una vez reiniciado, ejecuta 'flutter doctor' para confirmar que todo está bien."
