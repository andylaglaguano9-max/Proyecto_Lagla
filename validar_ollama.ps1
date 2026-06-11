<#
.SYNOPSIS
    Script de validación del servidor Ollama + Mistral 7B + ZeroTier
.DESCRIPTION
    Verifica: instalación, servicio, modelo, API local, API ZeroTier, firewall e inferencia.
.NOTES
    Ejecutar como Administrador para resultados completos.
    Autor: Arquitecto de Infraestructura IA
#>

$ErrorActionPreference = "Stop"
$ZEROTIER_PEER = "172.28.236.76"
$MODELO = "mistral:7b-instruct-v0.3-q8_0"
$PUERTO = 11434

$PASS = 0
$FAIL = 0
$WARN = 0

function Write-Result {
    param([string]$Test, [string]$Status, [string]$Detail)
    $icon = switch ($Status) {
        "PASS" { "[PASS]" }
        "FAIL" { "[FAIL]" }
        "WARN" { "[WARN]" }
    }
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
    }
    Write-Host "$icon $Test" -ForegroundColor $color
    if ($Detail) { Write-Host "       $Detail" -ForegroundColor Gray }
}

Clear-Host
Write-Host @"

=============================================
 VALIDACIÓN DEL SERVIDOR OLLAMA + MISTRAL 7B
=============================================
 Peer ZeroTier : $ZEROTIER_PEER
 Modelo        : $MODELO
 Puerto        : $PUERTO
=============================================

"@ -ForegroundColor Cyan

# [Prueba 1/7] Ollama instalado
Write-Host "[Prueba 1/7] Ollama instalado..." -ForegroundColor Cyan
try {
    $version = & ollama --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $version -match "\d+\.\d+\.\d+") {
        Write-Result -Test "Ollama instalado" -Status "PASS" -Detail $version
        $script:PASS++
    } else {
        throw "ollama --version no devolvió una versión válida"
    }
} catch {
    Write-Result -Test "Ollama instalado" -Status "FAIL" -Detail "No se encontró 'ollama'. Descárgalo desde https://ollama.com/download/windows"
    $script:FAIL++
}

# [Prueba 2/7] Servicio activo
Write-Host "[Prueba 2/7] Servicio Ollama..." -ForegroundColor Cyan
try {
    $svc = Get-Service -Name ollama -ErrorAction Stop
    if ($svc.Status -eq "Running") {
        Write-Result -Test "Servicio ollama" -Status "PASS" -Detail "Status: $($svc.Status), Startup: $($svc.StartType)"
        $script:PASS++
    } else {
        Write-Result -Test "Servicio ollama" -Status "FAIL" -Detail "Status: $($svc.Status). Ejecuta: Start-Service ollama"
        $script:FAIL++
    }
} catch {
    Write-Result -Test "Servicio ollama" -Status "FAIL" -Detail "Servicio no encontrado. Reinstala Ollama."
    $script:FAIL++
}

# [Prueba 3/7] Modelo descargado
Write-Host "[Prueba 3/7] Modelo disponible..." -ForegroundColor Cyan
try {
    $models = & ollama list 2>&1
    if ($LASTEXITCODE -eq 0 -and $models -match [regex]::Escape($MODELO)) {
        Write-Result -Test "Modelo $MODELO" -Status "PASS" -Detail "Modelo descargado y listo"
        $script:PASS++
    } else {
        Write-Result -Test "Modelo $MODELO" -Status "FAIL" -Detail "No encontrado. Ejecuta: ollama pull $MODELO"
        $script:FAIL++
    }
} catch {
    Write-Result -Test "Modelo $MODELO" -Status "FAIL" -Detail "Error al listar modelos"
    $script:FAIL++
}

# [Prueba 4/7] API local
Write-Host "[Prueba 4/7] API local..." -ForegroundColor Cyan
try {
    $resp = Invoke-RestMethod -Uri "http://localhost:$PUERTO" -Method Get -TimeoutSec 5
    if ($resp -match "Ollama is running") {
        Write-Result -Test "API local (localhost:$PUERTO)" -Status "PASS" -Detail $resp
        $script:PASS++
    } else {
        Write-Result -Test "API local" -Status "WARN" -Detail "Respuesta inesperada: $resp"
        $script:WARN++
    }
} catch {
    Write-Result -Test "API local (localhost:$PUERTO)" -Status "FAIL" -Detail "No responde. Verifica OLLAMA_HOST=0.0.0.0 y el firewall."
    $script:FAIL++
}

# [Prueba 5/7] API ZeroTier
Write-Host "[Prueba 5/7] API ZeroTier..." -ForegroundColor Cyan
try {
    $resp = Invoke-RestMethod -Uri "http://${ZEROTIER_PEER}:${PUERTO}" -Method Get -TimeoutSec 10
    if ($resp -match "Ollama is running") {
        Write-Result -Test "API ZeroTier (${ZEROTIER_PEER}:${PUERTO})" -Status "PASS" -Detail $resp
        $script:PASS++
    } else {
        Write-Result -Test "API ZeroTier" -Status "WARN" -Detail "Responde pero contenido inesperado: $resp"
        $script:WARN++
    }
} catch {
    Write-Result -Test "API ZeroTier (${ZEROTIER_PEER}:${PUERTO})" -Status "FAIL" -Detail "No se pudo conectar. Posibles causas:`n- ZeroTier no está activo (zerotier-cli status)`n- El peer no está en la misma red ZeroTier`n- Firewall bloqueando el puerto $PUERTO`n- El peer no configuró OLLAMA_HOST=0.0.0.0"
    $script:FAIL++
}

# [Prueba 6/7] Firewall
Write-Host "[Prueba 6/7] Firewall..." -ForegroundColor Cyan
try {
    $rule = Get-NetFirewallRule -DisplayName "Ollama API" -ErrorAction SilentlyContinue
    if ($rule) {
        $addr = (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule).LocalPort
        if ($addr -eq $PUERTO) {
            Write-Result -Test "Firewall puerto $PUERTO" -Status "PASS" -Detail "Regla 'Ollama API' activa"
            $script:PASS++
        } else {
            Write-Result -Test "Firewall puerto $PUERTO" -Status "WARN" -Detail "Regla existe pero no usa puerto $PUERTO"
            $script:WARN++
        }
    } else {
        $anyRule = Get-NetFirewallPortFilter | Where-Object { $_.LocalPort -eq $PUERTO -and $_.Protocol -eq "TCP" }
        if ($anyRule) {
            Write-Result -Test "Firewall puerto $PUERTO" -Status "PASS" -Detail "Puerto $PUERTO permitido por regla existente"
            $script:PASS++
        } else {
            Write-Result -Test "Firewall puerto $PUERTO" -Status "WARN" -Detail "Sin regla explícita. Ejecuta: .\configurar_firewall.ps1"
            $script:WARN++
        }
    }
} catch {
    Write-Result -Test "Firewall" -Status "WARN" -Detail "No se pudo leer reglas (ejecuta como Administrador)"
    $script:WARN++
}

# [Prueba 7/7] Inferencia real
Write-Host "[Prueba 7/7] Inferencia real..." -ForegroundColor Cyan
try {
    $body = @{
        model  = $MODELO
        prompt = "Respondé exactamente solo: OK"
        stream = $false
        options = @{ num_predict = 5 }
    } | ConvertTo-Json

    $resp = Invoke-RestMethod -Uri "http://localhost:${PUERTO}/api/generate" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -TimeoutSec 120

    if ($resp.response) {
        Write-Result -Test "Inferencia $MODELO" -Status "PASS" -Detail "Respuesta: '$($resp.response.Trim())'"
        $script:PASS++
    } else {
        Write-Result -Test "Inferencia" -Status "FAIL" -Detail "No se obtuvo respuesta del modelo"
        $script:FAIL++
    }
} catch {
    Write-Result -Test "Inferencia $MODELO" -Status "FAIL" -Detail "Error: $_"
    $script:FAIL++
}

# Resumen
Write-Host @"

=============================================
            RESUMEN DE VALIDACIÓN
=============================================
 Pruebas pasadas : $PASS / 7
 Pruebas falladas: $FAIL / 7
 Advertencias    : $WARN / 7
=============================================

"@ -ForegroundColor Cyan

if ($FAIL -eq 0 -and $PASS -eq 7) {
    Write-Host "SISTEMA OPERATIVO. Todo funciona correctamente." -ForegroundColor Green
    exit 0
} elseif ($FAIL -gt 0) {
    Write-Host "HAY FALLOS. Revisa las pruebas marcadas como FAIL arriba." -ForegroundColor Red
    exit 1
} else {
    Write-Host "FUNCIONAL CON ADVERTENCIAS. Revisa los WARN." -ForegroundColor Yellow
    exit 2
}
