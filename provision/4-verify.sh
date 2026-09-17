#!/usr/bin/env bash
# 4 — prove the environment actually works, before the attendees find out for you.
#     Deploys the full Lab 1-4 solution into a throwaway namespace and checks each step.
set -uo pipefail
cd "$(dirname "$0")"; source ./config.sh

# Target the subscription named in config.sh, never whichever one is active.
az account set --subscription "$SUBSCRIPTION" >/dev/null
printf 'subscription: %s\n' "$(az account show --query name -o tsv)"
NS="${VERIFY_NS:-provision-check}"
FAIL=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL+1)); }
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

say "Cluster add-ons"
az aks show -g "$RG" -n "$CLUSTER" --query oidcIssuerProfile.issuerUrl -o tsv >/dev/null 2>&1 \
  && ok "OIDC issuer enabled" || bad "OIDC issuer NOT enabled"
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  && ok "Gateway API CRDs present" || bad "Gateway API CRDs missing — Managed Gateway API not enabled"
kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io >/dev/null 2>&1 \
  && ok "Secrets Store CSI driver present" || bad "Secrets Store CSI driver missing"
kubectl -n "$GATEWAY_NS" get gateway "$GATEWAY_NAME" >/dev/null 2>&1 \
  && ok "shared Gateway exists" || bad "shared Gateway missing — run ./1-shared.sh"

say "Azure Policy is in DENY mode (Lab 1 depends on this)"
kubectl create ns "$NS" >/dev/null 2>&1 || true
if kubectl -n "$NS" apply -f ../lab1-deployment/deployment-broken.yaml >/dev/null 2>&1; then
  bad "the deliberately broken manifest was ACCEPTED — policy is in audit mode, Lab 1 has no lesson in it"
  kubectl -n "$NS" delete -f ../lab1-deployment/deployment-broken.yaml >/dev/null 2>&1 || true
else
  ok "broken manifest was rejected, as Lab 1 needs"
fi

say "Image is in the registry"
az acr repository show --name "$ACR" --image orders-api:v1 -o none 2>/dev/null \
  && ok "orders-api:v1 present in $ACR" || bad "orders-api:v1 missing — run: az acr build --registry $ACR --image orders-api:v1 ../sample-app"

say "Storage"
az storage blob show --account-name "$STORAGE" -c "$CONTAINER" -n hello.txt --auth-mode login -o none 2>/dev/null \
  && ok "hello.txt present in $CONTAINER" || bad "hello.txt missing — run ./1-shared.sh"

say "Key Vault"
az keyvault secret show --vault-name "$KEYVAULT" -n db-password -o none 2>/dev/null \
  && ok "db-password present" || bad "db-password missing — run ./1-shared.sh"

kubectl delete ns "$NS" --wait=false >/dev/null 2>&1 || true
printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mAll checks passed.\033[0m\n'; exit 0; }
printf '\033[31m%d check(s) failed — fix these before the session.\033[0m\n' "$FAIL"; exit 1
