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

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/customers` | List all customers |
| `GET` | `/api/credits` | List all credits |
| `POST` | `/api/credits/{id}/update` | Update a credit entry |
| `GET` | `/q/health` | Health check (liveness + readiness) |
| `GET` | `/q/health/live` | Liveness probe |
| `GET` | `/q/health/ready` | Readiness probe |

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
