<#
.SYNOPSIS
    Configura el Firewall de Windows para permitir el tráfico entrante al puerto de Ollama (11434).
.DESCRIPTION
    Crea reglas de firewall para los perfiles Domain, Private y Public.
.NOTES
    Ejecutar como Administrador.
#>

$ErrorActionPreference = "Stop"
$PUERTO = 11434
$RULE_NAME = "Ollama API"

Write-Host "[*] Configurando Firewall para Ollama (puerto $PUERTO)..." -ForegroundColor Cyan

$existing = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[*] La regla '$RULE_NAME' ya existe. Se omitirá." -ForegroundColor Yellow
} else {
    try {
        New-NetFirewallRule -DisplayName $RULE_NAME `
            -Description "Permitir tráfico entrante TCP al puerto $PUERTO para Ollama API" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $PUERTO `
            -Action Allow `
            -Profile Any `
            -ErrorAction Stop

        Write-Host "[OK] Regla '$RULE_NAME' creada exitosamente." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] No se pudo crear la regla: $_" -ForegroundColor Red
        Write-Host "[*] Posible causa: no ejecutaste como Administrador." -ForegroundColor Yellow
        exit 1
    }
}

$rule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
if ($rule) {
    Write-Host "[OK] Regla confirmada:" -ForegroundColor Green
    $rule | Format-Table DisplayName, Direction, Action, Enabled -AutoSize
    $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
    Write-Host "    Puerto: $($portFilter.LocalPort) | Protocolo: $($portFilter.Protocol)"
} else {
    Write-Host "[ERROR] La regla no se creó correctamente." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[*] Prueba de conectividad local:" -ForegroundColor Cyan
Test-NetConnection -ComputerName localhost -Port $PUERTO | Select-Object ComputerName, RemotePort, TcpTestSucceeded

Write-Host ""
Write-Host "[*] Para eliminar la regla en el futuro:" -ForegroundColor Gray
Write-Host "    Remove-NetFirewallRule -DisplayName '$RULE_NAME'" -ForegroundColor Gray
