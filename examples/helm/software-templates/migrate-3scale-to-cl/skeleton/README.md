# ${{values.name}} — Connectivity Link Migration

Migrated from **Red Hat 3scale API Management** to **Red Hat Connectivity Link** (Kuadrant).

## Migration Details

| Property | Value |
|----------|-------|
| **Application** | ${{values.name}} |
| **Source Namespace** | ${{values.sourceNamespace}} (3scale) |
| **Target Namespace** | ${{values.namespace}} (Connectivity Link) |
| **Auth Model** | ${{values.authModel}} |
| **Rate Limit** | ${{values.rateLimitPerMinute}} req/min |
| **Backend Service** | ${{values.backendServiceName}}:${{values.backendServicePort}} |

## Resources Created

| Resource | Kind | Purpose |
|----------|------|---------|
| Gateway | `gateway.networking.k8s.io/v1` | Istio ingress gateway |
| HTTPRoute | `gateway.networking.k8s.io/v1` | Routes traffic to backend service |
| AuthPolicy | `kuadrant.io/v1` | Authentication (${{values.authModel}}) |
| RateLimitPolicy | `kuadrant.io/v1` | Rate limiting |
| PlanPolicy | `extensions.kuadrant.io/v1alpha1` | Tiered usage plans (free/basic/pro) |
| APIProduct | `devportal.kuadrant.io/v1alpha1` | Developer portal listing |
| Route | `route.openshift.io/v1` | External access via OpenShift router |

## Comparison: 3scale vs Connectivity Link

| Aspect | 3scale (Before) | Connectivity Link (After) |
|--------|-----------------|---------------------------|
| **Gateway** | APIcast (3scale-managed) | Istio Gateway (Gateway API) |
| **Routing** | 3scale MappingRules | HTTPRoute |
| **Auth** | 3scale Product auth config | Kuadrant AuthPolicy |
| **Rate Limiting** | 3scale Application Plans | Kuadrant RateLimitPolicy + PlanPolicy |
| **Dev Portal** | 3scale Developer Portal | Kuadrant APIProduct + Backstage |
| **GitOps** | N/A (3scale admin UI) | ArgoCD + Git repository |
