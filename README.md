# Proyecto_Lagla

**Sistema distribuido de detección de prompts maliciosos para entornos SCADA y redes eléctricas.**

Arquitectura de microservicios interconectados via ZeroTier, compuesta por tres componentes principales: clasificador semántico (RoBERTa), middleware de seguridad y API bridge para modelo de lenguaje local (Ollama).

---

## Arquitectura del sistema

```mermaid
flowchart TB
    subgraph ZT["ZeroTier Network - 8286ac0e47f0ab7a"]
        
        subgraph MID["Jefferson - Middleware"]
            direction TB
            EP1["POST /check-prompt"] --> DEC{"Clasificar<br>prompt"}
        end

        subgraph CLS["Noelia - RoBERTa Classifier"]
            EP2["POST /classify"] --> RB["RoBERTa-base<br>SCADA Model"]
        end

        subgraph LLM["Andy - Mistral / Ollama"]
            API["api_chat.py<br>Port 8000"] --> OLL["Ollama Service<br>Port 11434"]
            OLL --> M["qwen2.5-coder:7b<br>Q8 - 4.1GB"]
        end

    end

    C["Client"] -->|"POST /check-prompt"| EP1
    DEC -->|"classify prompt"| EP2
    RB -->|"label + score"| DEC
    DEC -->|"forward prompt"| API
    API -->|"response"| DEC
    DEC -->|"final response"| C

    style ZT fill:#e8f4f8,stroke:#2c7a9e,stroke-width:2,stroke-dasharray: 6 3
    style MID fill:#fff3e0,stroke:#e65100,stroke-width:2
    style CLS fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2
    style LLM fill:#e3f2fd,stroke:#1565c0,stroke-width:2
    style C fill:#e8f5e9,stroke:#2e7d32,stroke-width:2
    style EP1 fill:#ffe0b2,stroke:#e65100
    style DEC fill:#ffe0b2,stroke:#e65100
    style EP2 fill:#e1bee7,stroke:#7b1fa2
    style RB fill:#ce93d8,stroke:#6a1b9a
    style API fill:#90caf9,stroke:#1565c0
    style OLL fill:#81c784,stroke:#2e7d32
    style M fill:#a5d6a7,stroke:#1b5e20
```

## Componente Andy: API Bridge Mistral / Ollama

API REST en Python puro (sin dependencias externas) que expone modelos de lenguaje locales a través de la red ZeroTier.

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/health` | Health check del servidor |
| `GET` | `/chat` | Respuesta de prueba |
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

### Stack tecnológico

| Componente | Tecnología |
|------------|-----------|
| Servidor HTTP | Python `http.server.ThreadingHTTPServer` |
| Backend LLM | Ollama 0.24.0 |
| Modelo | qwen2.5-coder:7b (Q8, 4.1 GB) |
| Red privada | ZeroTier 1.16.2 — Red: `8286ac0e47f0ab7a` |
| SO | Windows 11 Pro |

---

## Scripts incluidos

| Script | Descripción |
|--------|-------------|
| `api_chat.py` | Servidor API principal |
| `instalar_ollama.ps1` | Instalación automatizada de Ollama |
| `configurar_firewall.ps1` | Abre puertos en firewall de Windows |
| `validar_ollama.ps1` | Suite de verificación del entorno |
| `fix_zerotier.ps1` | Soluciona problemas de conexión ZeroTier |

---

## Personalizar el modelo

Edita las variables al inicio de `api_chat.py`:

```python
OLLAMA_HOST = "http://localhost:11434"
MODELO = "qwen2.5-coder:7b"   # Cambia por el modelo que prefieras
PUERTO = 8000
```

---

## Licencia

MIT
