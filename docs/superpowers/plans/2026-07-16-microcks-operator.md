# Microcks OLM Operator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `helmApps.microcks` with namespace-scoped OLM Subscription + `MicrocksInstall` under `components/microcks`.

**Architecture:** Expand `examples/helm/components/microcks` (Namespace, OperatorGroup, Subscription, MicrocksInstall, ConsoleLink). Remove Helm chart Application. Wipe cluster Helm leftovers and sync via Argo.

**Tech Stack:** OpenShift OLM (`community-operators` / package `microcks` / channel `stable`), CRD `microcks.github.io/v1alpha1 MicrocksInstall`, Argo CD GitOps.

## Global Constraints

- Wipe Helm data; no mock migration
- No async/Kafka in MicrocksInstall
- Keep in-cluster URL `http://microcks.microcks.svc.cluster.local:8080` for consumers
- Public hosts: `microcks.{{ domain }}`, `microcks-keycloak.{{ domain }}`
- Never commit API keys

---

### Task 1: Disable Helm Microcks app

**Files:**
- Modify: `examples/helm/values.yaml` (`helmApps` microcks entry)

- [ ] **Step 1:** Remove the entire `helmApps` entry with `id: microcks` (chart microcks.io/helm 1.14.0), or set `enabled: false` if the template supports it. Prefer **delete** the block so parent stops rendering `field-content-helm-microcks`.

- [ ] **Step 2:** Confirm `connectivityLink.apps` still has `id: microcks` with `path: microcks`, `skipDryRunOnMissingResource: true`.

- [ ] **Step 3:** Commit

```bash
git add examples/helm/values.yaml
git commit -m "Disable Microcks Helm chart Application in favor of Operator."
```

---

### Task 2: Operator + MicrocksInstall manifests

**Files:**
- Modify: `examples/helm/components/microcks/templates/all.yaml`
- Modify: `examples/helm/components/microcks/Chart.yaml` (bump description/appVersion if needed)

- [ ] **Step 1:** Replace `templates/all.yaml` with Namespace, OperatorGroup, Subscription, Role/RoleBinding for Argo (microcks.github.io), MicrocksInstall, ConsoleLink — sync-waves 0/1/2/4 as in the design spec.

- [ ] **Step 2:** MicrocksInstall must include:

```yaml
spec:
  name: microcks
  version: "latest"
  microcks:
    replicas: 1
    url: "microcks.{{ .Values.clusterDomain }}"
  postman:
    replicas: 1
  keycloak:
    install: true
    persistent: true
    volumeSize: 1Gi
    replicas: 1
    url: "microcks-keycloak.{{ .Values.clusterDomain }}"
  mongodb:
    install: true
    persistent: true
    volumeSize: 2Gi
    replicas: 1
```

- [ ] **Step 3:** Add on MicrocksInstall:
  `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`

- [ ] **Step 4:** Commit

```bash
git add examples/helm/components/microcks/
git commit -m "Install Microcks via OLM Subscription and MicrocksInstall CR."
```

---

### Task 3: Push and cluster cutover

**Files:** none (cluster ops)

- [ ] **Step 1:** `git push origin HEAD`

- [ ] **Step 2:** Confirm packagemanifest: `oc get packagemanifests microcks -n openshift-marketplace`

- [ ] **Step 3:** Delete `field-content-helm-microcks`; wipe Helm leftovers in `microcks` ns (deployments from chart, PVCs, optional full ns recreate if stuck)

- [ ] **Step 4:** Sync `field-content` and `field-content-microcks`; wait CSV + pods Ready

- [ ] **Step 5:** Verify UI 200, Service `microcks:8080`, Argo Healthy; no helm app

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Remove helmApps.microcks | Task 1 |
| OG + Subscription + MicrocksInstall + ConsoleLink | Task 2 |
| Wipe + sync + verify | Task 3 |
| Consumers unchanged | Task 3 verify Service name |

## Amendment (cluster cutover)

Ansible OLM OperatorHub package (`microcks` / `MicrocksInstall`) fails on this workshop cluster: `ValueError: too many values to unpack` in `k8s_facts` when OpenShift Virtualization CRDs are present. Switched to **Quarkus** [microcks/microcks-operator](https://github.com/microcks/microcks-operator) `0.0.10` via Git Helm chart + `kind: Microcks` (`microcks.io/v1alpha1`).
