# Proyecto_Lagla

Sistema distribuido de detección de prompts maliciosos para entornos SCADA y redes eléctricas. Compuesto por tres microservicios que se comunican via ZeroTier.

## Arquitectura del proyecto

```mermaid
graph TB
    subgraph ZeroTier["Red ZeroTier 8286ac0e47f0ab7a"]
        direction TB
        subgraph Andy["👤 Andy - Mistral (Puerto 8000)"]
            API[API Bridge<br>api_chat.py] -->|POST :11434/api/generate| OLLAMA[Ollama Service]
            OLLAMA --> MODELO[Modelo Local<br>qwen2.5-coder:7b]
        end
        subgraph Noelia["👤 Noelia - RoBERTa (FastAPI)"]
            ROBERTA[Clasificador Semántico<br>RoBERTa-base]
        end
        subgraph Jefferson["👤 Jefferson - Middleware"]
            MIDDLE[Middleware<br>Detección de Prompts]
        end
    end

    CLIENTE[Cliente HTTP] -->|POST /check-prompt| MIDDLE
    MIDDLE -->|POST /classify| ROBERTA
    MIDDLE -->|POST /chat| API
    MIDDLE --> CLIENTE

    style Andy fill:#e1f5fe,stroke:#01579b
    style Noelia fill:#f3e5f5,stroke:#7b1fa2
    style Jefferson fill:#fff3e0,stroke:#e65100
    style ZeroTier fill:#f5f5f5,stroke:#616161,stroke-dasharray: 5 5
```

## Componente actual (Andy): Mistral API Bridge

API REST en Python que funciona como puente entre clientes HTTP y Ollama, exponiendo modelos de lenguaje locales a través de la red ZeroTier.

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/health` | Health check del servidor |
| `GET` | `/chat` | Respuesta de prueba (hello world) |
| `POST` | `/chat` | Envía un prompt al modelo local |

### Ejemplo POST /chat

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explica qué eres en una línea"}'
```

Respuesta:

```json
{
  "modelo": "qwen2.5-coder:7b",
  "prompt": "Explica qué eres en una línea",
  "respuesta": "Soy un asistente de IA ejecutándose localmente en Ollama.",
  "status": "ok"
}
```

## Requisitos

- **Python 3.12+**
- **Ollama** instalado y corriendo en `http://localhost:11434`
- Un modelo descargado en Ollama (ej. `qwen2.5-coder:7b`, `mistral`, `llama3`, etc.)

## Instalación y uso

```powershell
# 1. Clonar o descargar el proyecto
cd MistralOllama

# 2. Iniciar el servidor
python api_chat.py

# 3. Probar health check
curl http://localhost:8000/health
```

El servidor se levanta en `http://0.0.0.0:8000`.

## Scripts incluidos

| Script | Descripción |
|--------|-------------|
| `api_chat.py` | Servidor API principal |
| `instalar_ollama.ps1` | Instalación automatizada de Ollama |
| `configurar_firewall.ps1` | Abre puertos en firewall de Windows |
| `validar_ollama.ps1` | Suite de verificación del entorno |
| `fix_zerotier.ps1` | Soluciona problemas de conexión ZeroTier |

## Personalizar el modelo

Edita las variables al inicio de `api_chat.py`:

```python
OLLAMA_HOST = "http://localhost:11434"
MODELO = "qwen2.5-coder:7b"   # Cambia por el modelo que prefieras
PUERTO = 8000
```

## Licencia

MIT
