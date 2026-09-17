#!/usr/bin/env bash
# 1 — everything that exists once, shared by all attendees.
# Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"; source ./config.sh

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

say "Checking the cluster has what the labs need"
OIDC=$(az aks show -g "$RG" -n "$CLUSTER" --query oidcIssuerProfile.issuerUrl -o tsv)
[ -n "$OIDC" ] || { echo "OIDC issuer is not enabled. Run: az aks update -g $RG -n $CLUSTER --enable-oidc-issuer --enable-workload-identity"; exit 1; }
echo "OIDC issuer: $OIDC"

for addon in azurepolicy azureKeyvaultSecretsProvider; do
  state=$(az aks show -g "$RG" -n "$CLUSTER" --query "addonProfiles.${addon}.enabled" -o tsv 2>/dev/null || echo "")
  [ "$state" = "true" ] && echo "  addon $addon: enabled" || echo "  !! addon $addon is NOT enabled"
done

say "Storage container, and the file Lab 3 reads"
az storage account show -g "$RG" -n "$STORAGE" -o none 2>/dev/null \
  || az storage account create -g "$RG" -n "$STORAGE" -l "$LOCATION" --sku Standard_LRS --allow-blob-public-access false -o none
az storage container create --account-name "$STORAGE" -n "$CONTAINER" --auth-mode login -o none
printf 'Hello from Azure Storage.\nYou read this file with no access key.\n' > /tmp/hello.txt
az storage blob upload --account-name "$STORAGE" -c "$CONTAINER" -n hello.txt \
  -f /tmp/hello.txt --auth-mode login --overwrite -o none
echo "  uploaded hello.txt"

say "Key Vault secret for Lab 2"
az keyvault secret set --vault-name "$KEYVAULT" -n db-password \
  --value "this-is-not-a-real-password" -o none
echo "  set db-password"

say "Shared Gateway for Lab 4"
kubectl get ns "$GATEWAY_NS" >/dev/null 2>&1 || kubectl create ns "$GATEWAY_NS"
kubectl apply -f - <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NS}
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.${DOMAIN}"
    allowedRoutes:
      namespaces:
        from: All          # attendees attach HTTPRoutes from their own namespaces
  infrastructure:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
YAML

say "Done. Now run ./2-attendees.sh"
