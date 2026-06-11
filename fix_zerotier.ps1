# ZeroTier TCP Fallback Fix
Write-Host "[*] Configurando TCP Fallback para ZeroTier..." -ForegroundColor Cyan

$confDir = "C:\ProgramData\ZeroTier\One\local.d"
$confFile = "$confDir\local.conf"

if (-not (Test-Path $confDir)) {
    New-Item -ItemType Directory -Path $confDir -Force | Out-Null
}

@"
{
    "settings": {
        "allowTcpFallbackRelay": true
    }
}
"@ | Set-Content -Path $confFile -Force

Write-Host "[OK] ConfiguraciOn TCP Fallback escrita" -ForegroundColor Green

Write-Host "[*] Reiniciando servicio ZeroTier..." -ForegroundColor Cyan
net stop ZeroTierOneService
Start-Sleep -Seconds 5
net start ZeroTierOneService
Start-Sleep -Seconds 10

Write-Host "[*] Estado actual:" -ForegroundColor Cyan
zerotier-cli status
zerotier-cli listnetworks

Write-Host "`n[*] Presiona Enter para salir..." -ForegroundColor Gray
Read-Host
