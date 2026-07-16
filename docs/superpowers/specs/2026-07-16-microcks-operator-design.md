# Design: Microcks via OLM Operator (replace Helm chart)

**Date:** 2026-07-16  
**Status:** Implemented (pivoted to Quarkus operator — see Amendment)  
**Cluster pattern:** `examples/helm` (field-content / Connectivity Link workshop)

## Problem

The Microcks **Helm chart** (`helmApps.microcks`, chart `1.14.0`) is unstable in this workshop:

- Ingress `microcks-grpc` without TLS secret → Argo Progressing/Degraded
- Secret/PVC password drift after Helm upgrades → Keycloak/Mongo auth failures
- Operational toil (force-delete PVCs, scrub ingress) without durable GitOps fix

## Goals

1. Install Microcks with the **Microcks Operator** (Ansible-based, OperatorHub / community-operators).
2. Full **GitOps**: OLM `Subscription` + `MicrocksInstall` in repo (not console-only).
3. **Wipe** the current Helm release and related PVCs/secrets; no data migration.
4. Keep workshop consumers working: in-cluster URL `http://microcks.microcks.svc.cluster.local:8080`, public UI host `microcks.{{ domain }}`, ConsoleLink.

## Non-goals

- Async API / Kafka / MQTT features
- Preserving existing mocks or Keycloak users
- Quarkus-based Microcks operator (still early)
- Changing 3scale / apicast privateBaseURL patterns beyond verifying Service name

## Decisions

| Decision | Choice |
|----------|--------|
| Install path | **A** — GitOps OLM (`community-operators`, package `microcks`, channel `stable`) |
| Data | **A** — Wipe Helm install + PVCs |
| Layout | Expand existing `examples/helm/components/microcks` (mirror `3scale-operator`) |
| Helm chart | Disable / remove `helmApps.microcks` entry |

## Architecture

```text
field-content (Helm parent)
  └─ Application field-content-microcks  (path: examples/helm/components/microcks)
        wave 0: Namespace microcks
        wave 1: OperatorGroup (targetNamespaces: [microcks])
                Subscription microcks → community-operators / stable
        wave 2: MicrocksInstall (after CRD from CSV)
        wave 4: ConsoleLink

REMOVED: field-content-helm-microcks (Helm source microcks.io/helm)
```

Consumers unchanged (verify Service `microcks` port `8080` after install):

- `enterprise-apis-3scale` / `apicast-scenarios` → `http://microcks.microcks.svc.cluster.local:8080`
- Import Job in `enterprise-apis-3scale` waits on that URL

## Manifest sketch

### Subscription (namespace-scoped)

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: microcks
  namespace: microcks
spec:
  channel: stable
  name: microcks
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
```

### MicrocksInstall (minimal OpenShift)

Aligned with upstream `openshift-minimal` + URLs from current Helm values:

```yaml
apiVersion: microcks.github.io/v1alpha1
kind: MicrocksInstall
metadata:
  name: microcks
  namespace: microcks
spec:
  name: microcks
  version: "latest"   # or pin to operator-supported release after cluster check
  microcks:
    replicas: 1
    url: microcks.{{ .Values.clusterDomain }}
  postman:
    replicas: 1
  keycloak:
    install: true
    persistent: true
    volumeSize: 1Gi
    replicas: 1
    url: microcks-keycloak.{{ .Values.clusterDomain }}
  mongodb:
    install: true
    persistent: true
    volumeSize: 2Gi
    replicas: 1
```

Sync notes:

- Application keeps `skipDryRunOnMissingResource: true` (CRD appears after InstallPlan).
- Optional: Argo sync-wave / `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` on the CR.
- Do **not** enable async/Kafka in the CR for the workshop.

## Cluster cutover

1. Merge Git changes (disable `helmApps.microcks`, expand component).
2. Delete Application `field-content-helm-microcks` (or let parent prune it).
3. Wipe namespace workload leftovers if needed: Helm secrets, PVCs `microcks-*`, orphan ingress.
4. Sync `field-content` → `field-content-microcks`; wait for CSV Succeeded + pods Ready.
5. Verify: UI `https://microcks.{{ domain }}` HTTP 200; Service DNS; re-run / rely on import Job when enterprise-apis syncs.

## Success criteria

- [ ] No `field-content-helm-microcks` Application
- [ ] `Subscription`/`CSV` healthy in `microcks`
- [ ] `MicrocksInstall` Ready; Microcks + Mongo + Keycloak pods Running
- [ ] UI HTTP 200; in-cluster mock URL reachable
- [ ] Argo app `field-content-microcks` Synced/Healthy without grpc ingress flap

## Risks / mitigations

| Risk | Mitigation |
|------|------------|
| `community-operators` package/channel naming differs on cluster | Confirm `oc get packagemanifests microcks -n openshift-marketplace` before pin; adjust Subscription |
| Service name ≠ `microcks` | Document actual Service; patch consumer values only if needed |
| CR applied before CRD | sync-wave + skipDryRun; retry sync |
| Operator recreates grpc Route/Ingress issues | Prefer operator OpenShift Routes; if grpc still noisy, leave async off and ignore grpc host |

## Amendment (implemented)

OperatorHub Ansible package (`MicrocksInstall`) **fails** on this workshop cluster: `ValueError: too many values to unpack` in `k8s_facts` when OpenShift Virtualization CRDs are present (known python-openshift bug).

**Shipped instead:**

- `helmApps.microcks-operator`: Git Helm chart `microcks/microcks-operator` `@0.0.10` → Quarkus operator
- `components/microcks`: `kind: Microcks` (`microcks.io/v1alpha1`) + ConsoleLink
- CR must set `keycloak.openshift.route.enabled: true` (and microcks) to avoid NPE in operator 0.0.10

Verified on cluster: Microcks status `READY`, UI HTTP 200, Service `microcks:8080`, no `field-content-helm-microcks`.
