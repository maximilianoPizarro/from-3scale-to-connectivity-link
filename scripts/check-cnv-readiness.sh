#!/usr/bin/env bash
# Validates whether the current OpenShift cluster meets requirements
# for installing OpenShift Virtualization (CNV / KubeVirt).
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

pass=0
warn=0
fail=0

result_pass()  { echo -e "  ${GREEN}[PASS]${NC}  $1"; ((pass++)); }
result_warn()  { echo -e "  ${YELLOW}[WARN]${NC}  $1"; ((warn++)); }
result_fail()  { echo -e "  ${RED}[FAIL]${NC}  $1"; ((fail++)); }

header() { echo -e "\n${BOLD}── $1${NC}"; }

# ── Prerequisites ──────────────────────────────────────────────────
command -v oc &>/dev/null || { echo "ERROR: 'oc' CLI not found in PATH"; exit 1; }
oc whoami &>/dev/null    || { echo "ERROR: Not logged in to an OpenShift cluster (run 'oc login' first)"; exit 1; }

echo -e "${BOLD}OpenShift Virtualization — Cluster Readiness Check${NC}"
echo "Cluster: $(oc whoami --show-server)"
echo "User:    $(oc whoami)"
echo "Date:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── 1. OpenShift version ──────────────────────────────────────────
header "1. OpenShift Version"
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "unknown")
OCP_MAJOR=$(echo "$OCP_VERSION" | cut -d. -f1)
OCP_MINOR=$(echo "$OCP_VERSION" | cut -d. -f2)
if [[ "$OCP_MAJOR" -ge 4 && "$OCP_MINOR" -ge 14 ]]; then
  result_pass "OpenShift $OCP_VERSION (>= 4.14 required for CNV 4.x)"
elif [[ "$OCP_MAJOR" -ge 4 ]]; then
  result_warn "OpenShift $OCP_VERSION — CNV installs on 4.x but 4.14+ is recommended"
else
  result_fail "OpenShift $OCP_VERSION — CNV requires OpenShift 4.x"
fi

# ── 2. Worker node CPU virtualization support ─────────────────────
header "2. Hardware Virtualization"
WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker="" -o name 2>/dev/null | wc -l)
if [[ "$WORKER_NODES" -eq 0 ]]; then
  result_warn "No nodes with role 'worker' found (checking all schedulable nodes instead)"
  WORKER_NODES=$(oc get nodes -o name 2>/dev/null | wc -l)
fi

VMX_NODES=$(oc get nodes -l 'cpu-feature.node.kubevirt.io/vmx' -o name 2>/dev/null | wc -l)
SVM_NODES=$(oc get nodes -l 'cpu-feature.node.kubevirt.io/svm' -o name 2>/dev/null | wc -l)
SCHEDULABLE=$(oc get nodes -l 'kubevirt.io/schedulable=true' -o name 2>/dev/null | wc -l)

HW_VIRT=$((VMX_NODES + SVM_NODES))
if [[ "$HW_VIRT" -gt 0 ]]; then
  result_pass "Hardware virtualization detected on $HW_VIRT node(s) (VMX: $VMX_NODES, SVM: $SVM_NODES)"
elif [[ "$SCHEDULABLE" -gt 0 ]]; then
  result_warn "No VMX/SVM labels but $SCHEDULABLE node(s) marked kubevirt.io/schedulable (nested/software emulation)"
else
  result_warn "No virtualization labels found — labels appear after CNV operator installs and runs virt-handler DaemonSet"
fi

# ── 3. Node resources ────────────────────────────────────────────
header "3. Node Resources"
TOTAL_CPU_MILLI=0
TOTAL_MEM_KI=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  cpu_raw=$(echo "$line" | awk '{print $1}')
  mem_raw=$(echo "$line" | awk '{print $2}')
  # Convert CPU: "15500m" → 15500 millicores, "16" → 16000 millicores
  if [[ "$cpu_raw" == *m ]]; then
    cpu_milli=${cpu_raw%m}
  else
    cpu_milli=$((cpu_raw * 1000))
  fi
  mem_ki=$(echo "$mem_raw" | sed 's/Ki//')
  TOTAL_CPU_MILLI=$((TOTAL_CPU_MILLI + cpu_milli))
  TOTAL_MEM_KI=$((TOTAL_MEM_KI + mem_ki))
done < <(oc get nodes -l node-role.kubernetes.io/worker="" -o jsonpath='{range .items[*]}{.status.allocatable.cpu}{" "}{.status.allocatable.memory}{"\n"}{end}' 2>/dev/null || \
         oc get nodes -o jsonpath='{range .items[*]}{.status.allocatable.cpu}{" "}{.status.allocatable.memory}{"\n"}{end}' 2>/dev/null)

TOTAL_CPU=$((TOTAL_CPU_MILLI / 1000))
TOTAL_MEM_GI=$((TOTAL_MEM_KI / 1048576))
echo "  Total allocatable: ${TOTAL_CPU} vCPU, ${TOTAL_MEM_GI} Gi memory"
if [[ "$TOTAL_CPU" -ge 8 && "$TOTAL_MEM_GI" -ge 32 ]]; then
  result_pass "Sufficient resources for CNV (minimum 8 vCPU / 32 Gi recommended)"
elif [[ "$TOTAL_CPU" -ge 4 && "$TOTAL_MEM_GI" -ge 16 ]]; then
  result_warn "Marginal resources — CNV will install but VM capacity is limited"
else
  result_fail "Insufficient resources (found ${TOTAL_CPU} vCPU / ${TOTAL_MEM_GI} Gi — need at least 8 vCPU / 32 Gi)"
fi

# ── 4. Default StorageClass ──────────────────────────────────────
header "4. Storage"
DEFAULT_SC=$(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
if [[ -n "$DEFAULT_SC" ]]; then
  result_pass "Default StorageClass: $DEFAULT_SC"
else
  result_warn "No default StorageClass — VM DataVolumes require a StorageClass (set one or specify per-VM)"
fi

RWX_SC=$(oc get storageclass -o json 2>/dev/null | python3 -c '
import json,sys
data=json.load(sys.stdin)
for sc in data.get("items",[]):
    name=sc["metadata"]["name"]
    print(name)
' 2>/dev/null | head -5)
if [[ -n "$RWX_SC" ]]; then
  result_pass "StorageClasses available: $(echo "$RWX_SC" | tr '\n' ', ' | sed 's/,$//')"
else
  result_warn "Could not enumerate StorageClasses"
fi

# ── 5. Existing CNV installation ─────────────────────────────────
header "5. Existing OpenShift Virtualization"
EXISTING_SUB=$(oc get subscription kubevirt-hyperconverged -n openshift-cnv -o name 2>/dev/null || true)
EXISTING_HC=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o name 2>/dev/null || true)
if [[ -n "$EXISTING_SUB" || -n "$EXISTING_HC" ]]; then
  result_warn "OpenShift Virtualization is already installed"
  [[ -n "$EXISTING_SUB" ]] && echo "    Subscription: $EXISTING_SUB"
  [[ -n "$EXISTING_HC" ]] && echo "    HyperConverged: $EXISTING_HC"
  HC_PHASE=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "unknown")
  echo "    Available: $HC_PHASE"
else
  result_pass "No existing CNV installation found — ready to install"
fi

# ── 6. CNV namespace ─────────────────────────────────────────────
header "6. Namespace"
if oc get namespace openshift-cnv &>/dev/null; then
  result_pass "Namespace openshift-cnv exists"
else
  result_pass "Namespace openshift-cnv does not exist (will be created during install)"
fi

# ── 7. Bare-metal vs nested virtualization ───────────────────────
header "7. Platform Type"
PLATFORM=$(oc get infrastructure cluster -o jsonpath='{.status.platform}' 2>/dev/null || echo "Unknown")
PLATFORM_TYPE=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}' 2>/dev/null || echo "Unknown")
echo "  Platform: $PLATFORM / $PLATFORM_TYPE"
case "$PLATFORM" in
  BareMetal|None)
    result_pass "Bare-metal platform — native hardware virtualization expected" ;;
  KubeVirt)
    result_warn "KubeVirt/RHDP nested environment — VMs use software emulation (functional but slower)" ;;
  AWS|GCP|Azure|VSphere|OpenStack)
    result_warn "Cloud/vSphere platform ($PLATFORM) — nested virtualization may require instance-type support" ;;
  *)
    result_warn "Platform '$PLATFORM' — verify hardware virtualization support" ;;
esac

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══ Summary ═══${NC}"
echo -e "  ${GREEN}PASS${NC}: $pass    ${YELLOW}WARN${NC}: $warn    ${RED}FAIL${NC}: $fail"
echo ""
if [[ "$fail" -gt 0 ]]; then
  echo -e "${RED}Cluster does NOT meet minimum requirements. Address FAIL items before installing CNV.${NC}"
  exit 1
elif [[ "$warn" -gt 0 ]]; then
  echo -e "${YELLOW}Cluster can likely run CNV but review WARN items. Proceeding is acceptable for demos/workshops.${NC}"
  exit 0
else
  echo -e "${GREEN}Cluster is ready for OpenShift Virtualization.${NC}"
  exit 0
fi
