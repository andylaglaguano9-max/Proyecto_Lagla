# Proyecto_Lagla

**Sistema distribuido de detección de prompts maliciosos para entornos SCADA y redes eléctricas.**

Arquitectura de microservicios interconectados via ZeroTier, compuesta por tres componentes principales: clasificador semántico (RoBERTa), middleware de seguridad y API bridge para modelo de lenguaje local (Ollama).

---

## Arquitectura del sistema

```mermaid
flowchart TB
    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    %%  CAPA EXTERNA - CLIENTE
    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    CLIENTE(("`**Cliente HTTP**`"))

    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    %%  RED ZEROTIER - ENTORNO DISTRIBUIDO
    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    subgraph ZT["Red Privada ZeroTier — 8286ac0e47f0ab7a"]
        direction TB

        %% ── JEFFERSON: MIDDLEWARE ──
        subgraph J["⚙️ Jefferson — Middleware de Seguridad"]
            direction TB
            MID_IN[("`**POST /check-prompt**`")]
            MID_DEC{{"`Análisis de<br>prompt`"}}
            MID_IN --> MID_DEC
        end

        %% ── NOELIA: ROBERTA CLASSIFIER ──
        subgraph N["🤖 Noelia — Clasificador Semántico RoBERTa"]
            direction TB
            ROB_API[("`**POST /classify**`")]
            ROB_MODEL[["`RoBERTa-base<br>SCADA / Redes Eléctricas`"]]
            ROB_API --> ROB_MODEL
        end

        %% ── ANDY: MISTRAL API BRIDGE ──
        subgraph A["🧠 Andy — API Bridge Mistral / Ollama"]
            direction TB
            API_BRIDGE[("`**API Bridge**<br>api_chat.py`")]
            subgraph OLLAMA_INTERNAL["Stack Local (localhost)"]
                direction LR
                OLLAMA_SVC["`**Ollama Service**<br>puerto :11434`"]
                MODELO[["`**Modelo Local**<br>qwen2.5-coder:7b<br>4.1 GB`"]]
                OLLAMA_SVC <--> MODELO
            end
            API_BRIDGE -->|POST /api/generate| OLLAMA_SVC
        end
    end

    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    %%  FLUJO DE DATOS
    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    CLIENTE -->|"POST http://IP-JEFFERSON:PUERTO/check-prompt"| MID_IN
    MID_DEC -->|"`**safe / suspicious** → consulta`"| ROB_API
    MID_DEC -->|"`**malicious** → bloquea`"| CLIENTE
    ROB_API -->|"`**label + score**`"| MID_DEC
    MID_DEC -->|"`prompt validado`"| API_BRIDGE
    API_BRIDGE -->|"`**respuesta generada**`"| MID_DEC
    MID_DEC -->|"`**respuesta final**`"| CLIENTE

    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    %%  ESTILOS
    %%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    style ZT fill:#f8f9fa,stroke:#495057,stroke-width:2px,stroke-dasharray: 8 4
    style J fill:#fff3e0,stroke:#e65100,stroke-width:2px
    style N fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style A fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style OLLAMA_INTERNAL fill:#e8f5e9,stroke:#2e7d32,stroke-width:1px
    style CLIENTE fill:#eeeeee,stroke:#424242,stroke-width:2px
    style MODELO fill:#c8e6c9,stroke:#1b5e20
    style MID_DEC fill:#ffe0b2,stroke:#e65100
```

## Leyenda del diagrama

| Símbolo | Significado |
|---------|-------------|
| `( )` | Endpoint de entrada/salida (API) |
| `{ }` | Decisión / lógica condicional |
| `[[ ]]` | Modelo de IA / datos persistentes |
| `[ ]` | Servicio o proceso interno |
| Línea sólida | Flujo de datos principal |
| Línea discontinua | Límite de red ZeroTier |

---

## Flujo de una solicitud

```
CLIENTE                          MIDDLEWARE (Jeff)                  ROBERTA (Noelia)
   │                                      │                              │
   │  POST /check-prompt                  │                              │
   │  {"prompt": "..."}                  │                              │
   ├─────────────────────────────────────►│                              │
   │                                      │  POST /classify              │
   │                                      │  {"prompt": "..."}          │
   │                                      ├─────────────────────────────►│
   │                                      │                              │
   │                                      │◄─────────────────────────────┤
   │                                      │  {"label":"safe",            │
   │                                      │   "score":0.98}             │
   │                                      │                              │
   │                                      │  ─── si safe/suspicious ──  │
   │                                      │                              │
   │                                      │  POST /chat                  │
   │                                      │  {"prompt": "..."}          │
   │                                      ├──────────────────────┐       │
   │                                      │                      │       │
   │                                      │           ┌──────────▼────┐  │
   │                                      │           │ ANDY - Ollama │  │
   │                                      │           │ api_chat.py   │  │
   │                                      │           │ → qwen2.5     │  │
   │                                      │           └──────────┬────┘  │
   │                                      │                      │       │
   │                                      │◄─────────────────────┘       │
   │                                      │  {"respuesta":"...",         │
   │                                      │   "status":"ok"}            │
   │                                      │                              │
   │◄─────────────────────────────────────┤                              │
   │  {"respuesta":"...","clasificacion": │                              │
   │   "safe","status":"ok"}             │                              │
```

---

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
