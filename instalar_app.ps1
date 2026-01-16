#!/usr/bin/env powershell

<#
    Script para instalar o app no Samsung S928B
    Uso: .\instalar_app.ps1
#>

$ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "📱 Script de Instalação - Taverna dos Vinhos" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Passo 1: Verificar ADB
if (!(Test-Path $ADB)) {
    Write-Host "❌ ADB não encontrado em: $ADB" -ForegroundColor Red
    exit 1
}
Write-Host "✓ ADB encontrado" -ForegroundColor Green

# Passo 2: Verificar dispositivos
Write-Host "`n📋 Verificando dispositivos conectados..." -ForegroundColor Yellow
$devices = & $ADB devices | Select-Object -Skip 1 | Where-Object {$_ -match 'device$'} | ForEach-Object {($_ -split '\s+')[0]}

if ($devices.Count -eq 0) {
    Write-Host "❌ Nenhum dispositivo conectado!" -ForegroundColor Red
    Write-Host "`n📌 Checklist:" -ForegroundColor Yellow
    Write-Host "  1. Conecte o cabo USB"
    Write-Host "  2. Abra: Configurações → Sobre → Número da compilação (toque 7x)"
    Write-Host "  3. Entre em: Opções do desenvolvedor"
    Write-Host "  4. Ative: Depuração USB"
    Write-Host "  5. Autorize no popup: 'Permitir depuração?'"
    exit 1
}

Write-Host "✓ Dispositivos encontrados:" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "  - $_" }

# Passo 3: Gerar APK
Write-Host "`n🔨 Gerando APK release..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao gerar APK" -ForegroundColor Red
    exit 1
}

$APK = "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path $APK)) {
    Write-Host "❌ APK não encontrado: $APK" -ForegroundColor Red
    exit 1
}

Write-Host "✓ APK gerado com sucesso" -ForegroundColor Green

# Passo 4: Desinstalar versão anterior
Write-Host "`n🗑️  Removendo versão anterior..." -ForegroundColor Yellow
& $ADB uninstall com.example.app_vinho_taverna 2>$null
Write-Host "✓ Versão anterior removida" -ForegroundColor Green

# Passo 5: Instalar APK
Write-Host "`n📥 Instalando APK no dispositivo..." -ForegroundColor Yellow
& $ADB install $APK

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK instalado com sucesso!" -ForegroundColor Green
    Write-Host "`n🚀 Iniciando aplicativo..." -ForegroundColor Yellow
    & $ADB shell am start -n com.example.app_vinho_taverna/.MainActivity
    Write-Host "✅ App aberto no seu dispositivo!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao instalar APK" -ForegroundColor Red
    exit 1
}

Write-Host "`n" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "✨ Instalação concluída com sucesso!" -ForegroundColor Green
