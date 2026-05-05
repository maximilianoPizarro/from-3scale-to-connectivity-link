---
layout: default
title: "Hands-On: Explore Deployed Applications"
nav_order: 13
---

In this activity you will explore the two pre-deployed example applications that showcase **Red Hat Connectivity Link** in action: **Neuralbank** (OIDC-protected customer API) and **NFL Wallet** (API Key-protected customer API). You will inspect their running resources, query the APIs from the terminal, and observe how each authentication model behaves.

## Part 1 — Neuralbank Stack Overview

Neuralbank is a financial-services demo stack that is already deployed in the `neuralbank-stack` namespace. It consists of a Quarkus backend, a PostgreSQL database, and an Istio Gateway protected by Kuadrant **OIDCPolicy** and **RateLimitPolicy**.

### 1.1 Inspect the running pods

```bash
oc get pods -n neuralbank-stack
```

You should see three pods:

| Pod | Role |
|-----|------|
| `neuralbank-backend-*` | Quarkus REST API (`/api/v1/customers`) |
| `neuralbank-db-*` | PostgreSQL database with seed data |
| `neuralbank-gateway-istio-*` | Istio ingress gateway (auto-managed) |

### 1.2 Check the Gateway and HTTPRoute

```bash
oc get gateway -n neuralbank-stack
oc get httproute -n neuralbank-stack
```

The Gateway is class `istio` and should report `PROGRAMMED: True`. The HTTPRoute forwards `/api` and `/q` paths to the backend service.

### 1.3 Verify the OIDCPolicy and RateLimitPolicy

```bash
oc get oidcpolicy -n neuralbank-stack -o wide
oc get ratelimitpolicy -n neuralbank-stack -o wide
```

The OIDCPolicy links to the Keycloak realm `neuralbank` and protects the HTTPRoute. The RateLimitPolicy caps traffic at **60 requests per minute** per authenticated user.

### 1.4 Test the API from the terminal

**Without a token** — the gateway redirects to Keycloak login (HTTP 302):

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  https://neuralbank.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers
```

Expected output:

```
HTTP 302
```

### 1.5 Browse in Developer Hub

1. Open **Developer Hub** and navigate to the **Catalog**.
2. Search for **neuralbank-stack** — you will find a System with three components (backend, frontend, database).
3. Click the **backend** component and explore:
   - **Overview** — ownership, lifecycle, links to Swagger and Grafana.
   - **Topology** — Kubernetes resources rendered by the plugin.
   - **API** — the OpenAPI spec for `/api/v1/customers` endpoints.
   - **TechDocs** — architecture, REST API reference, and OIDC authentication docs.

---

## Part 2 — NFL Wallet: Test API Key Authentication from the Terminal

NFL Wallet is a second pre-deployed demo application in the `nfl-wallet-prod` namespace. It uses the same Quarkus backend image but is protected by **AuthPolicy with API Key** instead of OIDC, making it ideal for machine-to-machine (M2M) access.

### 2.1 Inspect the running resources

```bash
oc get pods -n nfl-wallet-prod
oc get gateway -n nfl-wallet-prod
oc get httproute -n nfl-wallet-prod
oc get authpolicy -n nfl-wallet-prod -o wide
oc get ratelimitpolicy -n nfl-wallet-prod -o wide
```

Verify the AuthPolicy shows `ACCEPTED: True` and `ENFORCED: True`.

### 2.2 List the available API Keys

API Keys are stored as Kubernetes Secrets with special labels that Kuadrant/Authorino detects automatically:

```bash
oc get secrets -n nfl-wallet-prod -l kuadrant.io/apikey=true
```

Decode the admin key:

```bash
oc get secret nfl-wallet-apikey-admin -n nfl-wallet-prod \
  -o jsonpath='{.data.api_key}' | base64 -d ; echo
```

Output: `nfl-wallet-demo-key-2024`

### 2.3 Test — Request without API Key (expect 401)

```bash
curl -s -w "\nHTTP %{http_code}\n" \
  https://nfl-wallet.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers
```

Expected output:

```json
{"error":"Invalid or missing API key. Include header X-API-Key with a valid key."}
HTTP 401
```

### 2.4 Test — Request with an invalid API Key (expect 401)

```bash
curl -s -w "\nHTTP %{http_code}\n" \
  -H "X-API-Key: this-is-not-a-valid-key" \
  https://nfl-wallet.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers
```

Expected output:

```json
{"error":"Invalid or missing API key. Include header X-API-Key with a valid key."}
HTTP 401
```

### 2.5 Test — Request with a valid API Key (expect 200)

```bash
curl -s -w "\nHTTP %{http_code}\n" \
  -H "X-API-Key: nfl-wallet-demo-key-2024" \
  https://nfl-wallet.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers \
  | python3 -m json.tool
```

You should receive a JSON response with paginated customer records and `HTTP 200`.

### 2.6 Test — Request with the read-only key

```bash
curl -s -w "\nHTTP %{http_code}\n" \
  -H "X-API-Key: nfl-wallet-readonly-key-2024" \
  https://nfl-wallet.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers \
  | python3 -m json.tool
```

Both keys grant access; in a production scenario you would assign different scopes or RBAC rules to each key.

### 2.7 Quick rate-limit test

The RateLimitPolicy allows **120 requests per minute**. Run a burst to see the limit kick in:

```bash
for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "X-API-Key: nfl-wallet-demo-key-2024" \
    https://nfl-wallet.apps.cluster-qbg7r.dynamic.redhatworkshops.io/api/v1/customers)
  echo "Request $i: HTTP $code"
done
```

All 10 should return `200`. If you extend the loop to 130+ requests within one minute, the last ones will return `429 Too Many Requests`.

### 2.8 Browse in Developer Hub

1. Open **Developer Hub** and search for **nfl-wallet** in the Catalog.
2. Explore the **API** tab — the OpenAPI spec shows all `/api/v1/customers` endpoints with the `X-API-Key` security scheme.
3. Check the **APIProduct** linked to the API entity — it is Published and allows consumers to discover and request keys.
4. Open the **TechDocs** for usage instructions, Swagger UI access, and API Key authentication details.

---

## Part 3 — 3scale Pre-Deployed Applications (Migration Source)

The cluster also includes the same applications deployed with **Red Hat 3scale API Management**, enabling a side-by-side comparison.

### 3.1 Neuralbank on 3scale (OIDC)

```bash
oc get pods -n neuralbank-3scale
oc get product -n 3scale-system | grep neuralbank
```

The `neuralbank-oidc-product` 3scale Product protects the API with OIDC authentication via Keycloak, using APIcast as the gateway.

### 3.2 NFL Wallet on 3scale (API Key)

```bash
oc get pods -n nfl-wallet-3scale
oc get product -n 3scale-system | grep nfl-wallet
```

The `nfl-wallet-apikey-product` 3scale Product uses `user_key` authentication, with Application Plans for rate limiting.

### 3.3 Run the migration

1. In **Developer Hub**, go to **Create** and select **"Migrate from 3scale to Connectivity Link"**.
2. Fill in the parameters for one of the applications (e.g., `neuralbank-backend`, source: `neuralbank-3scale`, target: a new namespace).
3. The template generates all Connectivity Link manifests and deploys via ArgoCD.
4. Compare the behavior of both versions side by side.

---

## Summary: Full Comparison — 3scale vs Connectivity Link

| | 3scale (neuralbank-3scale) | CL (neuralbank-stack) | 3scale (nfl-wallet-3scale) | CL (nfl-wallet-prod) |
|---|---|---|---|---|
| **Auth type** | OIDC (Product) | OIDC (OIDCPolicy) | API Key (user_key) | API Key (AuthPolicy) |
| **Gateway** | APIcast | Istio Gateway | APIcast | Istio Gateway |
| **Routing** | MappingRules | HTTPRoute | MappingRules | HTTPRoute |
| **Rate Limit** | Application Plan | RateLimitPolicy | Application Plan | RateLimitPolicy |
| **Dev Portal** | 3scale Portal | APIProduct+Backstage | 3scale Portal | APIProduct+Backstage |
| **GitOps** | Partial (CRDs) | Full (ArgoCD) | Partial (CRDs) | Full (ArgoCD) |

### Authentication Model Comparison

| | Neuralbank (CL) | NFL Wallet (CL) |
|---|---|---|
| **Namespace** | `neuralbank-stack` | `nfl-wallet-prod` |
| **Auth mechanism** | OIDCPolicy (Keycloak JWT) | AuthPolicy (API Key header) |
| **Header** | `Authorization: Bearer <token>` | `X-API-Key: <key>` |
| **Unauthorized response** | 302 redirect to login | 401 JSON error |
| **Rate limit** | 60 req/min per user | 120 req/min global |
| **Best for** | Interactive users (web apps) | M2M integrations, scripts, CI/CD |
| **Key management** | Keycloak issues tokens | Kubernetes Secrets with labels |

Both patterns are powered by the same underlying stack: **Istio Gateway + HTTPRoute + Kuadrant policies**, demonstrating the flexibility of Red Hat Connectivity Link to support different authentication models within the same platform. The migration from 3scale can be automated using the **"Migrate from 3scale to Connectivity Link" Software Template** in Developer Hub.
