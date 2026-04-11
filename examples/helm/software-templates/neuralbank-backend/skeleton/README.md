# ${{ values.name }}

${{ values.description }}

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Java 17 |
| Framework | Quarkus 3.15.1 |
| REST | JAX-RS (quarkus-rest + jackson) |
| Health | SmallRye Health |
| Build | Maven |
| Container | UBI8 OpenJDK 17 (JVM mode) |
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

# The API is available at http://localhost:8080
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/customers` | List all customers |
| `GET` | `/api/credits` | List all credits |
| `POST` | `/api/credits/{id}/update` | Update a credit entry |
| `GET` | `/q/health` | Health check (liveness + readiness) |
| `GET` | `/q/health/live` | Liveness probe |
| `GET` | `/q/health/ready` | Readiness probe |

### Example requests

```bash
# List customers
curl -s https://${{ values.name }}-${{ values.namespace }}.${{ values.clusterDomain }}/api/customers | jq

# List credits
curl -s https://${{ values.name }}-${{ values.namespace }}.${{ values.clusterDomain }}/api/credits | jq

# Update a credit
curl -X POST https://${{ values.name }}-${{ values.namespace }}.${{ values.clusterDomain }}/api/credits/1/update \
  -H "Content-Type: application/json" \
  -d '{"amount": 5000, "status": "approved"}'
```

## Project Structure

```
${{ values.name }}/
├── src/main/java/com/neuralbank/api/
│   └── CreditResource.java          # REST API resource
├── src/main/resources/
│   └── application.properties        # Quarkus config
├── src/main/docker/
│   └── Dockerfile.jvm                # Container image (JVM)
├── manifests/
│   ├── deployment.yaml               # Kubernetes Deployment
│   ├── service.yaml                  # Kubernetes Service
│   ├── route.yaml                    # OpenShift Route
│   ├── pipeline.yaml                 # Tekton Pipeline
│   ├── pipelinerun.yaml              # Initial PipelineRun
│   ├── tasks.yaml                    # Tekton Tasks
│   ├── event-listener.yaml           # Tekton EventListener
│   ├── trigger-binding.yaml          # Tekton TriggerBinding
│   ├── trigger-template.yaml         # Tekton TriggerTemplate
│   ├── trigger-rbac.yaml             # RBAC for triggers
│   ├── gateway.yaml                  # Kuadrant Gateway
│   ├── httproute.yaml                # Gateway HTTPRoute
│   ├── authpolicy.yaml               # Kuadrant AuthPolicy (OIDC)
│   ├── ratelimitpolicy.yaml          # Kuadrant RateLimitPolicy
│   ├── planpolicy.yaml               # Kuadrant PlanPolicy
│   ├── oidcpolicy.yaml               # Kuadrant OIDC config
│   └── apiproduct.yaml               # Kuadrant APIProduct
├── argocd/
│   └── application.yaml              # ArgoCD Application
├── catalog-info.yaml                 # Backstage catalog entities
├── devfile.yaml                      # DevSpaces workspace config
└── pom.xml                           # Maven project
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
| Tags | `java`, `quarkus`, `rest-api`, `neuralbank` |

## CI/CD Pipeline

The Tekton pipeline runs automatically on git push (via webhook):

1. **git-clone** - Clone source from Gitea
2. **maven** - Build with `mvn package`
3. **buildah** - Build container image from `Dockerfile.jvm`
4. **deploy** - Rollout the new image

## Development with DevSpaces

Open directly in DevSpaces:

```
https://devspaces.${{ values.clusterDomain }}/#https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}
```

## Owner

- **User:** ${{ values.owner }}
- **Namespace:** ${{ values.namespace }}
- **System:** neuralbank
