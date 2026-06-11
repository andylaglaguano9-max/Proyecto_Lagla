<#
.SYNOPSIS
    Instalación automatizada de Ollama + Mistral 7B + configuración de red.
.DESCRIPTION
    1. Descarga e instala Ollama
    2. Descarga el modelo Mistral 7B Instruct v0.3 Q8
    3. Configura OLLAMA_HOST=0.0.0.0
    4. Abre el puerto 11434 en el firewall
    5. Verifica el estado final
.NOTES
    Ejecutar como Administrador.
#>

$ErrorActionPreference = "Stop"

$MODELO   = "mistral:7b-instruct-v0.3-q8_0"
$PUERTO   = 11434

Write-Host @"

=========================================
 INSTALADOR AUTOMÁTICO OLLAMA + MISTRAL
=========================================

"@ -ForegroundColor Cyan

# [Paso 1/5] Instalar Ollama
Write-Host "[Paso 1/5] Instalando Ollama..." -ForegroundColor Cyan

$existing = Get-Command ollama -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[OK] Ollama ya está instalado: $(ollama --version)" -ForegroundColor Green
} else {
    try {
        $url = "https://ollama.com/download/OllamaSetup.exe"
        $installer = "$env:TEMP\OllamaSetup.exe"
        Write-Host "    Descargando desde $url ..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        Write-Host "    Ejecutando instalador..."
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        Remove-Item $installer -Force

        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

        Write-Host "[OK] Ollama instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Falló la instalación de Ollama: $_" -ForegroundColor Red
        exit 1
    }
}

# [Paso 2/5] Descargar modelo
Write-Host "[Paso 2/5] Descargando modelo $MODELO ..." -ForegroundColor Cyan
try {
    & ollama pull $MODELO 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Modelo descargado." -ForegroundColor Green
    } else {
        throw "ollama pull falló con código $LASTEXITCODE"
    }
} catch {
    Write-Host "[ERROR] Falló la descarga del modelo: $_" -ForegroundColor Red
    exit 1
}

# [Paso 3/5] Configurar OLLAMA_HOST
Write-Host "[Paso 3/5] Configurando OLLAMA_HOST=0.0.0.0 ..." -ForegroundColor Cyan
try {
    [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
    Write-Host "[OK] Variable de entorno OLLAMA_HOST configurada permanentemente." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo configurar la variable: $_" -ForegroundColor Red
    exit 1
}

# [Paso 4/5] Configurar Firewall
Write-Host "[Paso 4/5] Configurando firewall (puerto $PUERTO)..." -ForegroundColor Cyan
try {
    $existing = Get-NetFirewallRule -DisplayName "Ollama API" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName "Ollama API" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $PUERTO `
            -Action Allow `
            -Profile Any -ErrorAction Stop
        Write-Host "[OK] Regla de firewall creada." -ForegroundColor Green
    } else {
        Write-Host "[OK] Regla de firewall ya existe." -ForegroundColor Green
    }
} catch {
    Write-Host "[ERROR] No se pudo configurar el firewall: $_" -ForegroundColor Red
    Write-Host "[*] Ejecuta como Administrador." -ForegroundColor Yellow
    exit 1
}

# [Paso 5/5] Reiniciar servicio y verificar
Write-Host "[Paso 5/5] Reiniciando servicio y verificando..." -ForegroundColor Cyan
try {
    Restart-Service -Name ollama -ErrorAction Stop
    Start-Sleep -Seconds 3

    $svc = Get-Service -Name ollama
    if ($svc.Status -eq "Running") {
        Write-Host "[OK] Servicio Ollama ejecutándose." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Servicio en estado: $($svc.Status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERROR] No se pudo reiniciar el servicio: $_" -ForegroundColor Red
    exit 1
}

Write-Host @"

=========================================
 INSTALACIÓN COMPLETADA EXITOSAMENTE
=========================================

Resumen:
  Ollama     : $(ollama --version)
  Modelo     : $MODELO
  Host       : 0.0.0.0 (accesible desde la red)
  Puerto     : $PUERTO
  Firewall   : Configurado
  Servicio   : $((Get-Service ollama).Status)

Próximos pasos:
  1. Ejecuta .\validar_ollama.ps1 para verificar todo el sistema
  2. Comparte tu IP ZeroTier con tu compañero
  3. Prueba desde su máquina: curl http://TU_IP_ZEROTIER:$PUERTO

=========================================

"@ -ForegroundColor Cyan
