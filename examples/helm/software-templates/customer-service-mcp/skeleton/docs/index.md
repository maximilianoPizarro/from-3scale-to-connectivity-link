# ${{ values.name }}

${{ values.description }}

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Java 17 |
| Framework | Quarkus 3.27.3 |
| Protocol | MCP (Model Context Protocol) via Quarkiverse MCP Server |
| Transport | Streamable HTTP + SSE |
| REST Client | MicroProfile REST Client (calls neuralbank-backend) |
| Health | SmallRye Health |
| Build | Maven |
| CI/CD | Tekton Pipelines |
| GitOps | ArgoCD |
| API Gateway | Kuadrant (AuthPolicy + RateLimitPolicy) |

## MCP Tools Available

The MCP server exposes customer management tools that AI assistants (like OpenShift Lightspeed) can invoke:

| Tool | Description |
|------|-------------|
| `createCustomer` | Create a new customer |
| `getCustomer` | Get customer by ID |
| `searchCustomers` | Search customers by criteria |
| `getCreditScore` | Get customer credit score |
| `activateCustomer` | Activate a customer account |
| `deactivateCustomer` | Deactivate a customer account |
| `getRiskLevel` | Get customer risk assessment |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/mcp` | MCP Streamable HTTP endpoint |
| `GET` | `/mcp/sse` | MCP Server-Sent Events endpoint |
| `GET` | `/q/health` | Health check |

## Quick Start

```bash
git clone https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}.git
cd ${{ values.name }}
mvn quarkus:dev
```

## CI/CD Pipeline

The Tekton pipeline runs automatically on git push (via webhook):

1. **git-clone** - Clone source from Gitea
2. **maven** - Build with `mvn package`
3. **buildah** - Build container image from `Dockerfile.jvm`
4. **deploy** - Rollout the new image

## Owner

- **User:** ${{ values.owner }}
- **Namespace:** ${{ values.namespace }}
- **System:** neuralbank
