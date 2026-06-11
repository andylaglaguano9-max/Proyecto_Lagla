# Guía Completa: Servidor Mistral 7B + Ollama + ZeroTier

> **Autor:** Arquitecto de Infraestructura IA
> **Fecha:** Junio 2026
> **ZeroTier Peer:** `172.28.236.76`

---

## Índice

1. [Arquitectura](#1-arquitectura)
2. [Requisitos](#2-requisitos)
3. [Instalación de Ollama](#3-instalación-de-ollama)
4. [Descargar Mistral 7B Instruct v0.3 Q8](#4-descargar-mistral-7b-instruct-v03-q8)
5. [Configurar Variable de Entorno](#5-configurar-variable-de-entorno)
6. [Firewall de Windows](#6-firewall-de-windows)
7. [Inicio Automático](#7-inicio-automático)
8. [ZeroTier](#8-zerotier)
9. [Verificación y Health Check](#9-verificación-y-health-check)
10. [Script de Validación Automática](#10-script-de-validación-automática)
11. [Troubleshooting](#11-troubleshooting)
12. [Referencia Rápida de Comandos](#12-referencia-rápida-de-comandos)

---

## 1. Arquitectura

```
[Internet]
     |
[ZeroTier Network]  <--->  IP: 172.28.236.76 (compañero)
     |
[Tu PC Windows 11]
     |
[Ollama Service :11434]
     |
[Mistral 7B Instruct v0.3 Q8]
```

- **Ollama** corre como servicio en Windows escuchando en `0.0.0.0:11434`
- **ZeroTier** provee la red privada virtual (VPN) para acceso remoto
- **Mistral 7B** se sirve mediante la API REST nativa de Ollama

## 2. Requisitos

| Componente | Versión |
|---|---|
| Windows | 11 Pro |
| Ollama | 0.24.0 |
| Modelo | Mistral 7B Instruct v0.3 (Q8) |
| ZeroTier | 1.16.2 |
| Disco | ~5 GB libres (modelo) |
| RAM | 8 GB mínimo (16 GB recomendado) |

## 3. Instalación de Ollama

### Opción A: Manual (descarga directa)

1. Descarga el instalador desde: https://ollama.com/download/windows
2. Ejecuta `OllamaSetup.exe`
3. Sigue el asistente (siguiente → siguiente → instalar)

### Opción B: Powershell (automático)

```powershell
# Descargar e instalar en silencio
Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile "$env:TEMP\OllamaSetup.exe"
Start-Process -FilePath "$env:TEMP\OllamaSetup.exe" -ArgumentList "/S" -Wait
Remove-Item "$env:TEMP\OllamaSetup.exe" -Force
```

### Verificar instalación

```powershell
ollama --version
# Debería mostrar: ollama version 0.24.0
```

## 4. Descargar Mistral 7B Instruct v0.3 Q8

```powershell
# Descargar el modelo
ollama pull mistral:7b-instruct-v0.3-q8_0

# Verificar que está descargado
ollama list
```

El modelo ocupa aproximadamente **4.1 GB** en `C:\Users\PC-MASTER\.ollama\models`.

## 5. Configurar Variable de Entorno (OLLAMA_HOST)

Ollama por defecto escucha solo en `127.0.0.1`. Para exponerlo en toda la red:

### Método 1: Variable de entorno permanente (recomendado)

```powershell
# Abre PowerShell como Administrador

# Configurar variable de sistema
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")

# Aplicar cambios al servicio
Restart-Service -Name ollama
```

### Método 2: Temporal (solo para pruebas)

```powershell
# Detener servicio, iniciar manualmente
net stop ollama
$env:OLLAMA_HOST="0.0.0.0"
ollama serve
```

## 6. Firewall de Windows

### Usando el script automatizado

```powershell
# Ejecutar como Administrador
.\configurar_firewall.ps1
```

### Manualmente

```powershell
# Abrir puerto 11434 para todas las redes
New-NetFirewallRule -DisplayName "Ollama API" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 11434 `
    -Action Allow `
    -Profile Any
```

### Verificar regla

```powershell
Get-NetFirewallRule -DisplayName "Ollama API"
```

## 7. Inicio Automático

Ollama ya se instala como servicio de Windows con inicio automático:

```powershell
# Verificar estado del servicio
Get-Service -Name ollama

# Si no está configurado como automático:
Set-Service -Name ollama -StartupType Automatic
Restart-Service -Name ollama
```

El servicio ejecuta `ollama serve` automáticamente al iniciar Windows.

## 8. ZeroTier

### Prerrequisitos

1. ZeroTier instalado (v1.16.2+)
2. Unirse a la misma red ZeroTier que tu compañero
3. Autorizar los peers en el [my.zerotier.com](https://my.zerotier.com)

### Verificar conectividad

```powershell
# Obtener tu IP ZeroTier
zerotier-cli listnetworks

# Hacer ping al compañero
ping 172.28.236.76

# Verificar puerto abierto desde el exterior
Test-NetConnection -ComputerName 172.28.236.76 -Port 11434
```

## 9. Verificación y Health Check

### Health Check Local

```powershell
# 1. Ollama está funcionando?
Invoke-RestMethod -Uri "http://localhost:11434" -Method Get
# Respuesta esperada: "Ollama is running"
```

### Health Check ZeroTier (remoto)

```powershell
# 2. API accesible desde la red ZeroTier?
Invoke-RestMethod -Uri "http://172.28.236.76:11434" -Method Get
# Respuesta esperada: "Ollama is running"
```

### Listar modelos disponibles

```powershell
# 3. Modelo descargado y disponible?
Invoke-RestMethod -Uri "http://localhost:11434/api/tags" | ConvertTo-Json
```

### Probar generación de texto

```powershell
# 4. Prueba de inferencia real
$body = @{
    model = "mistral:7b-instruct-v0.3-q8_0"
    prompt = "Hola, respondeme en una línea: ¿qué eres?"
    stream = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" | ConvertTo-Json
```

## 10. Script de Validación Automática

Ejecuta el script `validar_ollama.ps1` que automatiza TODAS las verificaciones:

```powershell
# Como Administrador (recomendado)
.\validar_ollama.ps1
```

El script valida:

| # | Prueba | Qué verifica |
|---|---|---|
| 1 | Ollama instalado | `ollama --version` responde |
| 2 | Servicio activo | `Get-Service ollama` = Running |
| 3 | Modelo descargado | `ollama list` contiene mistral |
| 4 | API local | `localhost:11434` responde |
| 5 | API ZeroTier | `172.28.236.76:11434` responde |
| 6 | Firewall abierto | Puerto 11434 accesible |
| 7 | Inferencia real | Genera 1 token de prueba |

## 11. Troubleshooting

### Problema: Ollama no inicia

```powershell
Get-EventLog -LogName Application -Source "ollama" -Newest 10 | Format-Table -Wrap
```

### Problema: API no responde en 0.0.0.0

```powershell
[Environment]::GetEnvironmentVariable("OLLAMA_HOST", "Machine")
# Si no es "0.0.0.0", configurarla (ver paso 5)
```

### Problema: No se puede conectar desde ZeroTier

```powershell
zerotier-cli status          # ZeroTier activo?
zerotier-cli listnetworks    # Redes disponibles?
Test-NetConnection -ComputerName localhost -Port 11434
Test-NetConnection -ComputerName 172.28.236.76 -Port 11434
```

### Problema: Modelo no responde o timeout

```powershell
ollama list                                    # Verificar modelo
ollama pull mistral:7b-instruct-v0.3-q8_0      # Forzar descarga
```

### Problema: Puertos ocupados

```powershell
netstat -ano | findstr :11434
Stop-Process -Id (Get-NetTCPConnection -LocalPort 11434).OwningProcess -Force
```

## 12. Referencia Rápida de Comandos

```powershell
# === GESTIÓN DEL SERVICIO ===
Get-Service -Name ollama                           # Ver estado
Restart-Service -Name ollama                       # Reiniciar
Set-Service -Name ollama -StartupType Automatic    # Auto-inicio

# === GESTIÓN DEL MODELO ===
ollama list                                        # Modelos instalados
ollama pull mistral:7b-instruct-v0.3-q8_0          # Descargar modelo
ollama rm mistral:7b-instruct-v0.3-q8_0            # Eliminar modelo

# === PRUEBAS API REST ===
curl http://localhost:11434                         # Health check
curl http://localhost:11434/api/tags                # Listar modelos

# === VARIABLES DE ENTORNO ===
$env:OLLAMA_HOST="0.0.0.0"                        # Temporal
[Environment]::SetEnvironmentVariable("OLLAMA_HOST","0.0.0.0","Machine")  # Permanente

# === ZEROTIER ===
zerotier-cli status                                # Estado
zerotier-cli listnetworks                          # Redes
ping 172.28.236.76                                 # Ping al peer
Test-NetConnection -ComputerName 172.28.236.76 -Port 11434  # Puerto abierto?

# === FIREWALL ===
.\configurar_firewall.ps1                          # Script automático
```
