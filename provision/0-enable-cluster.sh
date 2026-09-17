#!/usr/bin/env bash
# 0 — turn on the cluster features the labs depend on, and assign the policies
#     that make Lab 1 work.
#
# Run this ONCE per cluster, before 1-shared.sh. It changes the cluster, so it
# asks before doing anything.
set -euo pipefail
cd "$(dirname "$0")"; source ./config.sh

az account set --subscription "$SUBSCRIPTION" >/dev/null
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }

say "Target"
note "subscription: $(az account show --query name -o tsv)"
note "cluster:      $CLUSTER  (resource group $RG)"
read -r -p "    Continue? [y/N] " a; [ "$a" = "y" ] || { echo "Cancelled."; exit 1; }

# --- az version -------------------------------------------------------------
say "Checking azure-cli version"
CLI=$(az version --query '"azure-cli"' -o tsv)
if [ "$(printf '%s\n2.86.0\n' "$CLI" | sort -V | head -1)" != "2.86.0" ]; then
  echo "    azure-cli is $CLI. --enable-gateway-api needs 2.86.0 or higher."
  echo "    Run: az upgrade"
  exit 1
fi
note "azure-cli $CLI — fine"

# --- Azure Policy add-on ----------------------------------------------------
say "Azure Policy add-on"
if [ "$(az aks show -g "$RG" -n "$CLUSTER" --query addonProfiles.azurepolicy.enabled -o tsv 2>/dev/null)" = "true" ]; then
  note "already enabled"
else
  az aks enable-addons -g "$RG" -n "$CLUSTER" --addons azure-policy -o none
  note "enabled"
fi

# --- Managed Gateway API ----------------------------------------------------
say "Managed Gateway API"
if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  note "CRDs already present"
else
  az aks update -g "$RG" -n "$CLUSTER" --enable-gateway-api -o none
  note "enabled"
fi

# --- the policies Lab 1 is built on -----------------------------------------
say "Policy assignments — Lab 1 depends on these being DENY, not audit"
RG_SCOPE=$(az group show -n "$RG" --query id -o tsv)
ACR_LOGIN=$(az acr show -n "$ACR" --query loginServer -o tsv 2>/dev/null || echo "$ACR.azurecr.io")

assign() {  # assign <displayName> <assignmentName> <paramsJson>
  local display="$1" name="$2" params="$3" id
  id=$(az policy definition list --query "[?displayName=='$display'].id | [0]" -o tsv)
  if [ -z "$id" ]; then note "!! not found: $display"; return; fi
  az policy assignment create --name "$name" --display-name "$display" \
     --policy "$id" --scope "$RG_SCOPE" --params "$params" -o none 2>/dev/null \
     && note "assigned: $display" || note "already assigned: $display"
}

assign "Kubernetes cluster containers should only use allowed images" "lab-allowed-images" \
  "{\"effect\":{\"value\":\"deny\"},\"allowedContainerImagesRegex\":{\"value\":\"^${ACR_LOGIN}/.+$\"}}"

assign "Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits" "lab-resource-limits" \
  '{"effect":{"value":"deny"},"cpuLimit":{"value":"2"},"memoryLimit":{"value":"2Gi"}}'

assign "Kubernetes cluster pods and containers should only run with approved user and group IDs" "lab-nonroot" \
  '{"effect":{"value":"deny"},"runAsUserRule":{"value":"MustRunAsNonRoot"},"runAsGroupRule":{"value":"RunAsAny"},"supplementalGroupsRule":{"value":"RunAsAny"},"fsGroupRule":{"value":"RunAsAny"}}'

assign "Ensure cluster containers have readiness or liveness probes configured" "lab-probes" \
  '{"effect":{"value":"deny"},"probes":{"value":["livenessProbe","readinessProbe"]}}'

say "Done — but not yet in force"
cat <<'MSG'
    Gatekeeper syncs policy to the cluster on a schedule. Allow 15-20 minutes
    before the rules actually reject anything.

    Then prove it, rather than assuming:
        ./4-verify.sh
    It applies the deliberately broken Lab 1 manifest. If that manifest is
    ACCEPTED, the policies are not in force and Lab 1 has no lesson in it.

    Next: ./1-shared.sh
MSG
