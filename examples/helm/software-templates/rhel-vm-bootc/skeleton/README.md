# ${{values.vmName}} — RHEL Virtual Machine

RHEL virtual machine managed via **GitOps** (ArgoCD) on **OpenShift Virtualization**.

## VM Configuration

| Parameter        | Value                            |
|------------------|----------------------------------|
| **Name**         | `${{values.vmName}}`             |
| **Namespace**    | `${{values.namespace}}`          |
| **CPU**          | ${{values.cpuCores}} cores / ${{values.cpuSockets}} socket(s) / ${{values.cpuThreads}} thread(s) |
| **Memory**       | ${{values.memory}}               |
| **Root Disk**    | ${{values.rootDiskSize}}         |
| **Boot Source**  | ${{values.bootSource}}           |
| **Run Strategy** | ${{values.runStrategy}}          |

## GitOps Workflow

This repository is the **single source of truth** for the VM. ArgoCD watches the
`manifests/` directory and reconciles changes automatically.

To modify the VM (e.g. resize, change image):

1. Edit the relevant file under `manifests/`
2. Commit and push to the `main` branch
3. ArgoCD detects the change and syncs

## Accessing the VM

### SSH

```bash
# Via virtctl (recommended)
virtctl ssh cloud-user@${{values.vmName}} -n ${{values.namespace}}

# Via oc port-forward
oc port-forward svc/${{values.vmName}} 2222:22 -n ${{values.namespace}}
ssh -p 2222 cloud-user@localhost
```

### Console

```bash
virtctl console ${{values.vmName}} -n ${{values.namespace}}
```

{%- if values.bootSource === "bootc-image" %}

## bootc Lifecycle Management

This VM uses **bootc** (image-mode RHEL). The OS is delivered as an OCI container
image, enabling atomic updates and rollbacks.

### How bootc Updates Work

1. A **systemd timer** inside the guest runs `bootc update --apply` daily
2. The timer pulls the latest version of the bootc image and stages it
3. On the next reboot the new OS version is activated
4. If the update fails, bootc automatically rolls back to the previous image

### Updating the OS Image via GitOps

To update the base OS image for the VM:

1. Build a new bootc image (see below)
2. Push it to your registry with a new tag
3. Update `bootcImageUrl` in `manifests/virtualmachine.yaml`
4. Commit and push — ArgoCD will reconcile the DataVolume

### Building a Custom bootc Image

Create a `Containerfile`:

```dockerfile
FROM quay.io/centos-bootc/centos-bootc:stream9

# Install packages
RUN dnf install -y httpd vim-enhanced && \
    systemctl enable httpd && \
    dnf clean all

# Add configuration files
COPY my-config.conf /etc/myapp/config.conf
```

Build and push:

```bash
podman build -t quay.io/myorg/my-rhel-bootc:v1.1 .
podman push quay.io/myorg/my-rhel-bootc:v1.1
```

Then update the image reference in `manifests/virtualmachine.yaml` and push to
this repo.
{%- endif %}

{%- if values.enableConnectivityLink %}

## Connectivity Link

The VM service is exposed through the **Istio** mesh using **Gateway API** and
**Kuadrant** policies.

| Resource          | Name                          |
|-------------------|-------------------------------|
| Gateway           | `${{values.vmName}}-gateway`  |
| HTTPRoute         | `${{values.vmName}}-route`    |
{%- if values.authModel !== "none" %}
| AuthPolicy        | `${{values.vmName}}-auth`     |
{%- endif %}
{%- if values.rateLimitPerMinute > 0 %}
| RateLimitPolicy   | `${{values.vmName}}-ratelimit` |
{%- endif %}

Access the service:

```bash
# Get the gateway endpoint
oc get gateway ${{values.vmName}}-gateway -n ${{values.namespace}} -o jsonpath='{.status.addresses[0].value}'
```
{%- endif %}

## Manifests

```
manifests/
  virtualmachine.yaml      # KubeVirt VirtualMachine CR
  ssh-secret.yaml          # SSH public key
  cloudinit-secret.yaml    # Cloud-init user-data
  service.yaml             # Kubernetes Service
{%- if values.enableConnectivityLink %}
  gateway.yaml             # Gateway API Gateway
  httproute.yaml           # HTTPRoute
  authpolicy.yaml          # Kuadrant AuthPolicy
  ratelimitpolicy.yaml     # Kuadrant RateLimitPolicy
{%- endif %}
```
