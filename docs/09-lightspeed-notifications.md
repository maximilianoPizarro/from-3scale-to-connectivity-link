---
layout: default
title: "Lightspeed, MCP Gateway y Notificaciones"
nav_order: 9
---

Este módulo cubre tres capacidades integradas que potencian la experiencia del desarrollador: **Developer Hub Lightspeed** como asistente IA, **MCP Gateway** como extensión comunitaria de Kuadrant para exponer servidores MCP, y el sistema de **Notificaciones**.

## Developer Hub Lightspeed

Lightspeed es un asistente de IA integrado en Developer Hub. Permite realizar consultas en lenguaje natural sobre la plataforma, las plantillas y las mejores prácticas.

### Arquitectura Lightspeed

```mermaid
graph TB
    subgraph RHDH ["🔴 Developer Hub Pod"]
        direction LR
        UI["Lightspeed<br/>Plugin UI"]
        CORE["Lightspeed<br/>Core Service<br/>(port 8080)"]
        LLAMA["Llama Stack<br/>RAG + inference"]
        PG["PostgreSQL<br/>Conversation cache"]
    end

    subgraph LLM_INFRA ["🧠 LLM Infrastructure"]
        LITELLM["LiteLLM<br/>Proxy (port 4000)"]
        VLLM["vLLM<br/>Model Server"]
        MODEL["Qwen 2.5 7B<br/>Instruct"]
    end

    UI --> CORE
    CORE --> LLAMA
    CORE --> PG
    LLAMA --> LITELLM
    LITELLM --> VLLM
    VLLM --> MODEL

    style RHDH fill:#1a1a1a,color:#fff,stroke:#EE0000,stroke-width:2px
    style LLM_INFRA fill:#1a1a1a,color:#fff,stroke:#6a1b9a,stroke-width:2px
    style UI fill:#EE0000,color:#fff
    style CORE fill:#0066CC,color:#fff
    style LLAMA fill:#6a1b9a,color:#fff
    style PG fill:#4078c0,color:#fff
    style LITELLM fill:#ef7b4d,color:#fff
    style VLLM fill:#609926,color:#fff
    style MODEL fill:#609926,color:#fff
```

Los componentes se ejecutan como sidecars junto al backend de Developer Hub:

- **Lightspeed Core Service**: orquesta las solicitudes y mantiene historial de conversaciones en PostgreSQL.
- **Llama Stack**: gestiona el acceso a modelos y la base de datos vectorial con documentación del producto (RAG).
- **LiteLLM**: proxy unificado que gestiona las conexiones a los modelos de lenguaje (compartido con OpenShift Lightspeed).

### Probar consultas

| Pregunta sugerida | Qué obtendrás |
| --- | --- |
| "How do I create and use Software Templates?" | Flujo de scaffolding y golden paths |
| "What components make up the Neuralbank platform?" | Arquitectura backend, frontend y MCP |
| "How are Tekton pipelines configured for CI/CD?" | Configuración de pipelines y triggers |
| "What is the OIDCPolicy pattern in Connectivity Link?" | Patrón de autenticación con Keycloak |

## MCP Gateway (Extensión Comunitaria de Kuadrant)

**MCP Gateway** es una extensión comunitaria del operador **Kuadrant** que permite registrar, exponer y gestionar servidores MCP (Model Context Protocol) a través del API Gateway de forma declarativa.

### Flujo interactivo 3D — MCP Gateway

<div id="mcp-gateway-3d"></div>
<script>document.addEventListener('DOMContentLoaded', function() { initMCPGateway3D('mcp-gateway-3d'); });</script>

> Arrastrá para rotar. Click en **⛶ Fullscreen** para ver a pantalla completa. Las partículas muestran cómo OpenShift Lightspeed llama herramientas a través del MCP Gateway hacia los servidores MCP y el clúster.

### Flujo de registro MCP

```mermaid
sequenceDiagram
    actor Admin as Platform Admin
    participant K8s as Kubernetes API
    participant CTRL as MCP Gateway<br/>Controller
    participant GW as Gateway<br/>(mcp-gateway)
    participant OLS as OpenShift<br/>Lightspeed

    Admin->>K8s: 1. Apply MCPGatewayExtension CR
    K8s-->>CTRL: 2. Controller activado
    Admin->>K8s: 3. Apply MCPServerRegistration CRs
    CTRL->>K8s: 4. Crea HTTPRoute por cada MCP server
    CTRL->>GW: 5. Registra rutas en Gateway
    OLS->>GW: 6. Consume MCP servers via Gateway
    GW-->>OLS: 7. Proxy a k8s-mcp / ocp-mcp servers
```

### Componentes del MCP Gateway

```mermaid
graph LR
    subgraph NS ["openshift-lightspeed namespace"]
        direction TB
        LITELLM2["LiteLLM Proxy<br/>(port 4000)"]
        K8S_MCP["k8s-mcp-server<br/>Kubernetes ops"]
        OCP_MCP["ocp-mcp-server<br/>OpenShift ops"]
        
        subgraph MCP_GW ["MCP Gateway"]
            GW3["Gateway<br/>(mcp-gateway)"]
            HR_K8S["HTTPRoute<br/>→ k8s-mcp"]
            HR_OCP["HTTPRoute<br/>→ ocp-mcp"]
        end
    end

    subgraph CONSUMERS ["Consumers"]
        OLS3["OpenShift<br/>Lightspeed"]
        DEVLS2["Developer Hub<br/>Lightspeed"]
    end

    OLS3 --> LITELLM2
    DEVLS2 --> LITELLM2
    OLS3 --> GW3
    GW3 --> HR_K8S
    GW3 --> HR_OCP
    HR_K8S --> K8S_MCP
    HR_OCP --> OCP_MCP

    style NS fill:#1a1a1a,color:#fff,stroke:#EE0000,stroke-width:2px
    style MCP_GW fill:#2a2a2a,color:#fff,stroke:#609926
    style CONSUMERS fill:#1a1a1a,color:#fff,stroke:#0066CC
    style LITELLM2 fill:#ef7b4d,color:#fff
    style K8S_MCP fill:#0066CC,color:#fff
    style OCP_MCP fill:#0066CC,color:#fff
    style GW3 fill:#609926,color:#fff
    style HR_K8S fill:#4078c0,color:#fff
    style HR_OCP fill:#4078c0,color:#fff
    style OLS3 fill:#EE0000,color:#fff
    style DEVLS2 fill:#EE0000,color:#fff
```

### Recursos involucrados

| Custom Resource | Función |
| --- | --- |
| `MCPGatewayExtension` | Activa el controlador MCP en Kuadrant |
| `MCPServerRegistration` | Registra un MCP server y crea su HTTPRoute automáticamente |
| `Gateway` (mcp-gateway) | Punto de entrada para todos los MCP servers registrados |
| `HTTPRoute` | Enruta tráfico del Gateway al MCP server correspondiente |

### OpenShift Lightspeed + MCP

**OpenShift Lightspeed** se beneficia del MCP Gateway al poder ejecutar operaciones sobre el clúster a través de los MCP servers:

```mermaid
graph TB
    USER["👤 Admin / Dev"] --> OLS_UI["OpenShift Lightspeed<br/>(Console UI)"]
    OLS_UI --> OLS_SVC["OLS Service<br/>(OLSConfig CR)"]
    OLS_SVC --> LITELLM3["LiteLLM → LLM"]
    OLS_SVC --> MCPGW2["MCP Gateway"]
    MCPGW2 --> K8S2["k8s-mcp:<br/>pods, services,<br/>deployments..."]
    MCPGW2 --> OCP2["ocp-mcp:<br/>routes, builds,<br/>imagestreams..."]

    style USER fill:#151515,color:#fff,stroke:#EE0000
    style OLS_UI fill:#EE0000,color:#fff
    style OLS_SVC fill:#0066CC,color:#fff
    style LITELLM3 fill:#ef7b4d,color:#fff
    style MCPGW2 fill:#609926,color:#fff
    style K8S2 fill:#0066CC,color:#fff
    style OCP2 fill:#0066CC,color:#fff
```

Ejemplos de lo que Lightspeed puede hacer con MCP:

- "List all pods in namespace `user1-neuralbank`"
- "Show me the routes in `neuralbank-stack`"
- "Describe the deployment `neuralbank-backend`"
- "What services are running in my namespace?"

## Sistema de notificaciones

Developer Hub notifica a los desarrolladores sobre eventos de la plataforma a través de dos canales:

### Flujo de notificaciones

```mermaid
sequenceDiagram
    actor Dev as Desarrollador
    participant Hub as Developer Hub
    participant Notif as Notifications Backend
    participant Mail as Mailpit (SMTP)

    Dev->>Hub: Ejecuta Software Template
    Hub->>Hub: Scaffolding completo
    Hub->>Notif: POST /api/notifications
    Notif->>Dev: 🔔 Notificación in-app
    Notif->>Mail: 📧 Envío email SMTP
    Mail-->>Dev: Email con detalles del despliegue
```

| Canal | Cómo acceder | Ejemplo |
| --- | --- | --- |
| **In-app** | Icono campana en Developer Hub | "Neuralbank Backend deployed successfully" |
| **Email** | Interfaz web de Mailpit | Email a `userN@developer-hub.local` con detalles |

Las plantillas envían notificaciones automáticas al crear o eliminar componentes, proporcionando visibilidad completa sobre el ciclo de vida.
