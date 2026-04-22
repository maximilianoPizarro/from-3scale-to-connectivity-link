---
layout: default
title: "Migration Spec: 3scale to Connectivity Link"
nav_exclude: true
---

# Migration Specification: Red Hat 3scale to Red Hat Connectivity Link

This document defines the concepts, architecture comparison, and migration flow for moving API management from **Red Hat 3scale API Management** to **Red Hat Connectivity Link** (powered by Kuadrant).

## 1. Definitions

### 1.1 Red Hat 3scale API Management Concepts

| Concept | Definition |
|---------|-----------|
| **Product** | A logical API definition that groups backend APIs, authentication settings, and application plans. Maps to a public-facing API endpoint. |
| **Backend** | An internal API endpoint (private base URL) that 3scale routes traffic to. A Product references one or more Backends via usage declarations. |
| **MappingRule** | A pattern-based routing rule that maps HTTP method + URL path to a metric. Equivalent to path-based routing in Gateway API. |
| **APIcast** | The 3scale API gateway (based on NGINX/OpenResty). Available as hosted (managed by 3scale) or self-managed. Handles authentication, rate limiting, and traffic proxying. |
| **Application Plan** | Defines rate limits, quotas, and pricing tiers for API consumers. Applications subscribe to a plan to get credentials. |
| **Application** | An API consumer identity bound to a plan. For API Key auth, the application holds the `user_key`. For OIDC, it holds the `client_id`/`client_secret`. |
| **ActiveDoc** | An OpenAPI specification attached to a Product, published in the 3scale Developer Portal. |
| **Developer Portal** | A self-service portal where API consumers discover APIs, subscribe to plans, and manage credentials. |

### 1.2 Red Hat Connectivity Link (Kuadrant) Concepts

| Concept | Definition |
|---------|-----------|
| **Gateway** | A Kubernetes Gateway API resource (`gateway.networking.k8s.io/v1`). Defines the ingress point backed by an Istio dataplane. |
| **HTTPRoute** | A Kubernetes Gateway API resource that routes HTTP traffic to backend Services based on path, header, or host matching. |
| **AuthPolicy** | A Kuadrant CRD (`kuadrant.io/v1`) that attaches authentication rules to a Gateway or HTTPRoute. Supports API Key (Kubernetes Secrets), JWT/OIDC, mTLS. |
| **OIDCPolicy** | A higher-level Kuadrant CRD (`extensions.kuadrant.io/v1alpha1`) that provides full OIDC flow (redirect, callback, token validation) on an HTTPRoute. Generates AuthPolicy under the hood. |
| **RateLimitPolicy** | A Kuadrant CRD (`kuadrant.io/v1`) that enforces rate limits on a Gateway or HTTPRoute. Counters can be global or per-identity. |
| **PlanPolicy** | A Kuadrant CRD (`extensions.kuadrant.io/v1alpha1`) that defines tiered usage plans (free/basic/pro) with different rate limits, identified by labels on API key secrets. |
| **APIProduct** | A Kuadrant CRD (`devportal.kuadrant.io/v1alpha1`) that publishes an API to the Kuadrant Developer Portal (Backstage plugin). |
| **Authorino** | The policy engine that evaluates AuthPolicy rules. Supports JWT, API Key, OPA, pattern-matching, and more. |
| **Limitador** | The rate-limiting engine that enforces RateLimitPolicy counters. Exposes gRPC for Envoy integration. |

## 2. Feature Comparison Table

| Feature | Red Hat 3scale | Red Hat Connectivity Link |
|---------|---------------|---------------------------|
| **API Gateway** | APIcast (NGINX-based, proprietary config) | Istio Gateway (Envoy-based, Gateway API standard) |
| **Routing** | MappingRules (method + pattern → metric) | HTTPRoute (Gateway API standard, path/header/host matching) |
| **OIDC Auth** | Product → OIDC issuer config in admin UI | OIDCPolicy or AuthPolicy with JWT issuer on HTTPRoute |
| **API Key Auth** | Product → user_key / app_id+app_key | AuthPolicy with apiKey selector on labeled Secrets |
| **Rate Limiting** | Application Plans (limits per metric per plan) | RateLimitPolicy (limits per route, per identity, per window) |
| **Usage Tiers** | Application Plans (free/basic/pro with different limits) | PlanPolicy (CEL predicates on identity metadata) |
| **Dev Portal** | 3scale Developer Portal (CMS-based) | Kuadrant APIProduct + Backstage plugin |
| **API Docs** | ActiveDoc (OpenAPI in 3scale portal) | APIProduct with OpenAPI URL + Backstage TechDocs |
| **Configuration** | 3scale Admin UI / API / CRDs | Kubernetes CRDs + GitOps (ArgoCD) |
| **GitOps** | Partial (3scale Operator CRDs) | Native (all config is YAML in Git) |
| **Multi-tenancy** | Built-in (provider/tenant accounts) | Kubernetes namespaces + RBAC |
| **Observability** | 3scale Analytics dashboard | Prometheus/Grafana + OpenTelemetry + Kiali |
| **TLS Management** | 3scale admin config | TLSPolicy (automatic ACME/Let's Encrypt) |
| **DNS Management** | External | DNSPolicy (Route 53, Cloud DNS) |

## 3. Authentication Model Mapping

### 3.1 OIDC Authentication (Neuralbank scenario)

| Aspect | 3scale (neuralbank-3scale) | Connectivity Link (neuralbank-stack) |
|--------|---------------------------|--------------------------------------|
| **Resource** | `Product` with `oidc` auth | `OIDCPolicy` on HTTPRoute |
| **Issuer** | `issuerEndpoint` in Product spec | `provider.issuerURL` in OIDCPolicy |
| **Client ID** | 3scale Application → OIDC client | `provider.clientID` in OIDCPolicy |
| **Token validation** | APIcast validates JWT | Authorino validates JWT |
| **Redirect flow** | APIcast → Keycloak → APIcast callback | OIDCPolicy → Keycloak → callback HTTPRoute |
| **Unauthenticated** | 403 from APIcast | 302 redirect to Keycloak login |
| **Namespace** | `neuralbank-3scale` | `neuralbank-stack` |

### 3.2 API Key Authentication (NFL Wallet scenario)

| Aspect | 3scale (nfl-wallet-3scale) | Connectivity Link (nfl-wallet-prod) |
|--------|---------------------------|--------------------------------------|
| **Resource** | `Product` with `userkey` auth | `AuthPolicy` with `apiKey` selector |
| **Credential** | `user_key` query parameter | `X-API-Key` header |
| **Storage** | 3scale database (Application) | Kubernetes Secrets with labels |
| **Validation** | APIcast looks up user_key | Authorino matches labeled Secrets |
| **Unauthenticated** | 403 from APIcast | 401 JSON error from Authorino |
| **Namespace** | `nfl-wallet-3scale` | `nfl-wallet-prod` |

## 4. Rate Limiting Comparison

| Aspect | 3scale Application Plans | Kuadrant RateLimitPolicy + PlanPolicy |
|--------|-------------------------|---------------------------------------|
| **Definition** | Per-metric limits in Plan YAML | Per-route limits in RateLimitPolicy |
| **Tiers** | Plans: basic (60/min), premium (300/min) | PlanPolicy tiers: free (10/min), basic (60/min), pro (300/min) |
| **Counter scope** | Per-application (user_key or client_id) | Per-identity (CEL expression on `auth.identity`) |
| **Enforcement** | APIcast → 3scale backend (Redis) | Envoy → Limitador (Rust-based, in-cluster) |
| **Exceeded response** | 429 with rate limit headers | 429 with rate limit headers |
| **Daily quotas** | Separate daily/monthly limits in Plan | `limits.daily` in PlanPolicy |

## 5. Migration Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          OpenShift Cluster                              │
│                                                                         │
│  ┌──────────────────────────┐    ┌──────────────────────────┐          │
│  │   3scale (Source)         │    │  Connectivity Link (Target)│          │
│  │                          │    │                          │          │
│  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │          │
│  │  │ neuralbank-3scale  │  │    │  │ neuralbank-stack   │  │          │
│  │  │ (OIDC via Product) │  │    │  │ (OIDC via OIDCPolicy)│ │          │
│  │  │                    │  │    │  │                    │  │          │
│  │  │ APIcast ──→ Backend│  │    │  │ Gateway ──→ Backend│  │          │
│  │  └────────────────────┘  │    │  └────────────────────┘  │          │
│  │                          │    │                          │          │
│  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │          │
│  │  │ nfl-wallet-3scale  │  │    │  │ nfl-wallet-prod    │  │          │
│  │  │ (API Key via Prod) │  │    │  │ (API Key via AuthPol)│ │          │
│  │  │                    │  │    │  │                    │  │          │
│  │  │ APIcast ──→ Backend│  │    │  │ Gateway ──→ Backend│  │          │
│  │  └────────────────────┘  │    │  └────────────────────┘  │          │
│  │                          │    │                          │          │
│  │  3scale Operator         │    │  Kuadrant Operator       │          │
│  │  APIManager              │    │  Istio / Service Mesh    │          │
│  └──────────────────────────┘    └──────────────────────────┘          │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │  Developer Hub (Backstage)                                │          │
│  │  ┌─────────────────────────────────────────────────────┐ │          │
│  │  │ Migration Software Template                          │ │          │
│  │  │ (generates Gateway + HTTPRoute + AuthPolicy + ...)   │ │          │
│  │  └─────────────────────────────────────────────────────┘ │          │
│  └──────────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 6. Migration Flow (Step by Step)

| Step | Action | Details |
|------|--------|---------|
| 1 | **Identify the 3scale Product** | Note the authentication type (OIDC or API Key), backend URL, mapping rules, and application plans. |
| 2 | **Open Developer Hub** | Navigate to **Create** → select **"Migrate from 3scale to Connectivity Link"** template. |
| 3 | **Fill parameters** | Provide app name, source namespace (3scale), target namespace (CL), auth model, backend service details. |
| 4 | **Template generates manifests** | Gateway, HTTPRoute, AuthPolicy (OIDC or API Key), RateLimitPolicy, PlanPolicy, APIProduct, Route. |
| 5 | **Publish to Gitea** | The scaffolder pushes the generated manifests to a Gitea repository. |
| 6 | **ArgoCD syncs** | An ArgoCD Application is created; it syncs the manifests to the target namespace. |
| 7 | **Verify in target namespace** | Check that Gateway is `PROGRAMMED`, AuthPolicy is `ENFORCED`, and the API responds correctly. |
| 8 | **Compare side-by-side** | Both 3scale and Connectivity Link namespaces coexist. Test the same API through both gateways. |
| 9 | **Decommission 3scale** | Once validated, disable the 3scale Product and delete the source namespace. |

## 7. Mapping Rules to HTTPRoute Conversion

### Example: Neuralbank

**3scale MappingRules:**
```yaml
mappingRules:
  - httpMethod: GET
    pattern: "/api/v1/customers$"
    metricMethodRef: hits
  - httpMethod: POST
    pattern: "/api/v1/customers$"
    metricMethodRef: hits
  - httpMethod: GET
    pattern: "/q/openapi$"
    metricMethodRef: hits
```

**Equivalent HTTPRoute:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: neuralbank-backend-svc
          port: 8080
    - matches:
        - path:
            type: PathPrefix
            value: /q
      backendRefs:
        - name: neuralbank-backend-svc
          port: 8080
```

## 8. Application Plans to PlanPolicy Conversion

### Example: Basic and Premium plans

**3scale Application Plans:**
```yaml
applicationPlans:
  basic:
    name: "Basic Plan"
    limits:
      - period: minute
        value: 60
        metricMethodRef:
          systemName: hits
  premium:
    name: "Premium Plan"
    limits:
      - period: minute
        value: 300
        metricMethodRef:
          systemName: hits
```

**Equivalent PlanPolicy:**
```yaml
apiVersion: extensions.kuadrant.io/v1alpha1
kind: PlanPolicy
spec:
  plans:
    - tier: basic
      predicate: |
        auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "basic"
      limits:
        daily: 1000
        custom:
          - limit: 60
            window: "1m"
    - tier: pro
      predicate: |
        auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "pro"
      limits:
        daily: 10000
        custom:
          - limit: 300
            window: "1m"
```

## 9. Official Documentation

| Product | Documentation |
|---------|---------------|
| **Red Hat 3scale API Management** | [https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/) |
| **Red Hat Connectivity Link** | [https://docs.redhat.com/en/documentation/red_hat_connectivity_link/](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/) |
| **Kuadrant (upstream)** | [https://docs.kuadrant.io/](https://docs.kuadrant.io/) |
| **Gateway API** | [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/) |
| **Red Hat Developer Hub** | [https://docs.redhat.com/en/documentation/red_hat_developer_hub/](https://docs.redhat.com/en/documentation/red_hat_developer_hub/) |
