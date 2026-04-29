# ${{ values.vmName }}

${{ values.description }}

## Technology Stack

| Layer | Technology |
|-------|-----------|
| OS | Red Hat Enterprise Linux (bootc image) |
| Runtime | OpenShift Virtualization (KubeVirt) |
| GitOps | ArgoCD |
| Networking | Gateway API + Istio |
| API Management | Kuadrant (Connectivity Link) |

## Architecture

```
Internet
  │
  ▼
┌─────────────┐
│   Gateway    │  (Istio ingress)
└──────┬──────┘
       │
┌──────▼──────┐
│  HTTPRoute   │  ${{ values.vmName }}-route
└──────┬──────┘
       │
┌──────▼──────┐
│   Service    │  ${{ values.vmName }}-svc (port 80 → 80)
└──────┬──────┘
       │
┌──────▼──────┐
│  VirtualMachine  │  RHEL bootc
└─────────────┘
```

## Access

| Method | Details |
|--------|---------|
| URL | `https://${{ values.vmName }}-route-${{ values.namespace }}.apps.${{ values.clusterDomain }}/` |
| SSH | `virtctl ssh cloud-user@${{ values.vmName }} -n ${{ values.namespace }}` |

{%- if values.enableConnectivityLink and values.authModel === "apikey" %}

## API Key Authentication

This VM is protected with API Key authentication via Kuadrant.

| Item | Value |
|------|-------|
| Header | `X-API-Key` |
| Cookie | `vm-api-key` |
| Demo Key | `${{ values.vmName }}-demo-key` |
| Plan | basic (1000 req/day, 60 req/min) |

### Usage with curl

```bash
curl -H "X-API-Key: ${{ values.vmName }}-demo-key" \
  https://${{ values.vmName }}-route-${{ values.namespace }}.apps.${{ values.clusterDomain }}/
```

### Browser access

Visit the URL in your browser. A login form will appear asking for your API Key. Enter it and the cookie will be set automatically.

### Managing API Keys

Generate and manage API Keys from the **Dev Portal** in Developer Hub. Available plans:

| Plan | Daily Limit | Per-Minute Limit |
|------|------------|-----------------|
| free | 100 | 10 |
| basic | 1,000 | 60 |
| pro | 10,000 | 300 |
{%- endif %}

{%- if values.enableConnectivityLink and values.authModel === "oidc" %}

## OIDC Authentication

This VM is protected with OpenID Connect authentication via Red Hat Build of Keycloak.

| Item | Value |
|------|-------|
| Realm | `${{ values.keycloakRealm }}` |
| Issuer | `https://rhbk.${{ values.clusterDomain }}/realms/${{ values.keycloakRealm }}` |
{%- endif %}

## GitOps

Source repository: [Gitea](https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.vmName }}-vm)

Changes pushed to the repo are automatically synced by ArgoCD to the cluster.

## Owner

- **User:** ${{ values.owner }}
- **Namespace:** ${{ values.namespace }}
- **System:** ${{ values.owner }}-vms
