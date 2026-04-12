# ${{ values.name }}

${{ values.description }}

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | HTML5 / CSS3 / JavaScript |
| Fonts | Google Fonts (Red Hat Display) |
| Icons | Font Awesome |
| Runtime (dev) | Python 3 HTTP server |
| Runtime (prod) | Apache HTTPD (UBI8) |
| CI/CD | Tekton Pipelines |
| GitOps | ArgoCD |
| IDE | Red Hat DevSpaces |

## Application

Static single-page application for the Neuralbank platform. Provides a credit management UI that consumes the `neuralbank-backend` REST API.

### Features

- Customer listing
- Credit application form
- Credit status dashboard
- Responsive design with Red Hat branding

## Quick Start

```bash
git clone https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}.git
cd ${{ values.name }}
python3 -m http.server 8080
```

## CI/CD Pipeline

The Tekton pipeline runs automatically on git push (via webhook):

1. **git-clone** - Clone source from Gitea
2. **buildah** - Build container image from `Dockerfile`
3. **deploy** - Rollout the new image

## Owner

- **User:** ${{ values.owner }}
- **Namespace:** ${{ values.namespace }}
- **System:** neuralbank
