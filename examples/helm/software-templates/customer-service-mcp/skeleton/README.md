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
| Container | UBI9 OpenJDK 21 (JVM mode) |
| CI/CD | Tekton Pipelines |
| GitOps | ArgoCD |
| IDE | Red Hat DevSpaces |
| API Gateway | Kuadrant (AuthPolicy + RateLimitPolicy) |

## Quick Start (Local Development)

```bash
# Clone the repository
git clone https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}.git
cd ${{ values.name }}

# Run in dev mode (hot-reload)
mvn quarkus:dev

# MCP endpoint: http://localhost:8080/mcp
# SSE endpoint: http://localhost:8080/mcp/sse
```

### Testing with MCP Inspector

```bash
npx @anthropic-ai/mcp-inspector http://localhost:8080/mcp/sse
```

## API Endpoints

### MCP Protocol

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/mcp` | MCP Streamable HTTP endpoint |
| `GET` | `/mcp/sse` | MCP Server-Sent Events endpoint |
| `GET` | `/q/health` | Health check |

### MCP Tools Available

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

### Backend Dependency

This MCP server calls the `neuralbank-backend` REST API internally:

```
http://neuralbank-backend.${{ values.namespace }}.svc.cluster.local:8080/api/v1/customers
```

## Project Structure

```
${{ values.name }}/
├── src/main/java/com/neuralbank/
│   ├── client/
│   │   └── CustomerClient.java           # REST client to backend
│   ├── dto/
│   │   ├── request/
│   │   │   ├── CreateCustomerRequest.java
│   │   │   └── UpdateCustomerRequest.java
│   │   └── response/
│   │       ├── CustomerResponse.java
│   │       ├── CreditScoreResponse.java
│   │       └── PageResponse.java
│   ├── enums/
│   │   └── CustomerType.java
│   └── tools/
│       └── CustomerTools.java            # MCP tool definitions
├── src/main/resources/
│   └── application.properties            # Quarkus + MCP config
├── src/main/docker/
│   └── Dockerfile.jvm                    # Container image
├── manifests/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── route.yaml
│   ├── pipeline.yaml
│   ├── pipelinerun.yaml
│   ├── tasks.yaml
│   ├── event-listener.yaml
│   ├── trigger-binding.yaml
│   ├── trigger-template.yaml
│   ├── trigger-rbac.yaml
│   ├── gateway.yaml
│   ├── httproute.yaml
│   ├── authpolicy.yaml
│   ├── ratelimitpolicy.yaml
│   ├── planpolicy.yaml
│   ├── oidcpolicy.yaml
│   └── apiproduct.yaml
├── argocd/
│   └── application.yaml
├── catalog-info.yaml
├── devfile.yaml
└── pom.xml
```

## Backstage Labels

| Label/Annotation | Value |
|-----------------|-------|
| `backstage.io/kubernetes-id` | `${{ values.name }}` |
| `backstage.io/kubernetes-namespace` | `${{ values.namespace }}` |
| `argocd/app-name` | `${{ values.name }}` |
| `argocd/app-namespace` | `openshift-gitops` |
| `janus-idp.io/tekton` | `${{ values.name }}` |
| `tektonci/build-namespace` | `${{ values.namespace }}` |
| Tags | `java`, `quarkus`, `mcp`, `neuralbank` |

## CI/CD Pipeline

The Tekton pipeline runs automatically on git push (via webhook):

1. **git-clone** - Clone source from Gitea
2. **maven** - Build with `mvn package`
3. **buildah** - Build container image from `Dockerfile.jvm`
4. **deploy** - Rollout the new image

## Integration with OpenShift Lightspeed

Register this MCP server in the OLSConfig to make tools available to the AI assistant:

```yaml
mcpServers:
  - name: ${{ values.name }}
    timeout: 30
    url: 'http://${{ values.name }}.${{ values.namespace }}.svc.cluster.local:8080/mcp'
```

## Development with DevSpaces

Open directly in DevSpaces:

```
https://devspaces.${{ values.clusterDomain }}/#https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}
```

## Owner

- **User:** ${{ values.owner }}
- **Namespace:** ${{ values.namespace }}
- **System:** neuralbank
