# Genera el APK de Control Asistencia
# Nota: la ruta del usuario tiene espacio ("ACER NITRO"). Este script compila desde C:\control_asistencia.

$ErrorActionPreference = "Stop"

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = "C:\control_asistencia"

$flutterHome = "C:\flutter"
if (-not (Test-Path "$flutterHome\bin\flutter.bat")) {
    Write-Host "Copiando Flutter a C:\flutter (solo la primera vez)..." -ForegroundColor Yellow
    robocopy "$env:USERPROFILE\flutter" $flutterHome /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
}

if (-not (Test-Path "C:\pub-cache")) {
    New-Item -ItemType Directory -Path "C:\pub-cache" -Force | Out-Null
}

if (-not (Test-Path $buildRoot)) {
    New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
}

Write-Host "Sincronizando codigo..." -ForegroundColor Cyan
robocopy $src $buildRoot /E /XD build .dart_tool .idea /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

$env:Path = "$flutterHome\bin;$env:Path"
$env:FLUTTER_ROOT = $flutterHome
$env:PUB_CACHE = "C:\pub-cache"
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA "Android\Sdk"

Set-Location $buildRoot

Write-Host "Obteniendo dependencias..." -ForegroundColor Cyan
flutter pub get

Write-Host "Compilando APK release..." -ForegroundColor Cyan
flutter build apk --release

$apk = Join-Path $buildRoot "build\app\outputs\flutter-apk\app-release.apk"
$dest = Join-Path $src "Control-Asistencia.apk"

if (Test-Path $apk) {
    Copy-Item $apk $dest -Force
    Write-Host ""
    Write-Host "APK listo:" -ForegroundColor Green
    Write-Host $dest
} else {
    Write-Host "No se encontro el APK. Ejecute: flutter doctor" -ForegroundColor Red
    exit 1
}
