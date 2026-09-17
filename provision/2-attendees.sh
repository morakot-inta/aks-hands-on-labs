#!/usr/bin/env bash
# 2 — one namespace, one federated credential and the role assignments per attendee.
#
# RUN THIS AT LEAST AN HOUR BEFORE THE SESSION. A federated credential takes time
# to propagate; a token requested too soon fails with AADSTS70021.
#
# Safe to re-run: every step is create-if-missing.
set -euo pipefail
cd "$(dirname "$0")"; source ./config.sh

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }

OIDC=$(az aks show -g "$RG" -n "$CLUSTER" --query oidcIssuerProfile.issuerUrl -o tsv)
AKS_ID=$(az aks show -g "$RG" -n "$CLUSTER" --query id -o tsv)
KV_ID=$(az keyvault show -g "$RG" -n "$KEYVAULT" --query id -o tsv)
SA_ID=$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)
CONTAINER_SCOPE="${SA_ID}/blobServices/default/containers/${CONTAINER}"

mapfile -t ROWS < <(grep -v '^[[:space:]]*#' attendees.txt | grep -v '^[[:space:]]*$')
[ ${#ROWS[@]} -gt 0 ] || { echo "attendees.txt is empty"; exit 1; }
say "${#ROWS[@]} attendees"

# --- managed identities: one per 20 attendees ------------------------------
IDENTITY_COUNT=$(( (${#ROWS[@]} + MAX_FIC_PER_IDENTITY - 1) / MAX_FIC_PER_IDENTITY ))
say "Creating $IDENTITY_COUNT managed identity(ies) — max $MAX_FIC_PER_IDENTITY credentials each"
declare -a ID_CLIENT ID_PRINCIPAL ID_NAME
for ((n=0; n<IDENTITY_COUNT; n++)); do
  name="${IDENTITY_PREFIX}-${n}"
  az identity show -g "$RG" -n "$name" -o none 2>/dev/null \
    || az identity create -g "$RG" -n "$name" -l "$LOCATION" -o none
  ID_NAME[$n]="$name"
  ID_CLIENT[$n]=$(az identity show -g "$RG" -n "$name" --query clientId -o tsv)
  ID_PRINCIPAL[$n]=$(az identity show -g "$RG" -n "$name" --query principalId -o tsv)
  note "$name  client=${ID_CLIENT[$n]}"

  # the identity needs to reach storage and key vault; attendees never do
  for pair in "Storage Blob Data Contributor|$CONTAINER_SCOPE" "Key Vault Secrets User|$KV_ID"; do
    role="${pair%%|*}"; scope="${pair##*|}"
    az role assignment create --assignee-object-id "${ID_PRINCIPAL[$n]}" \
       --assignee-principal-type ServicePrincipal --role "$role" --scope "$scope" -o none 2>/dev/null \
       && note "  granted: $role" || note "  already had: $role"
  done
done

# --- per attendee ----------------------------------------------------------
say "Namespaces, federated credentials and access"
i=0
for row in "${ROWS[@]}"; do
  NS="${row%%,*}"; UPN="${row##*,}"
  NS="$(echo "$NS" | tr -d '[:space:]')"; UPN="$(echo "$UPN" | tr -d '[:space:]')"
  n=$(( i / MAX_FIC_PER_IDENTITY ))
  printf '\n  [%2d] %-14s %s  -> %s\n' "$((i+1))" "$NS" "$UPN" "${ID_NAME[$n]}"

  kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null
  note "namespace ready"

  # IMPORTANT: sequential. Creating these concurrently under one identity returns 409.
  if az identity federated-credential show --identity-name "${ID_NAME[$n]}" -g "$RG" \
       --name "fc-${NS}" -o none 2>/dev/null; then
    note "federated credential already exists"
  else
    az identity federated-credential create \
      --name "fc-${NS}" --identity-name "${ID_NAME[$n]}" -g "$RG" \
      --issuer "$OIDC" \
      --subject "system:serviceaccount:${NS}:${SERVICE_ACCOUNT}" \
      --audience api://AzureADTokenExchange -o none
    note "federated credential created"
  fi

  # the attendee needs to be able to fetch cluster credentials...
  az role assignment create --assignee "$UPN" \
     --role "Azure Kubernetes Service Cluster User Role" --scope "$AKS_ID" -o none 2>/dev/null \
     && note "granted AKS Cluster User Role" || note "already had AKS Cluster User Role"

  # ...and to edit things, but only inside their own namespace
  OID=$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null || echo "")
  if [ -n "$OID" ]; then
    kubectl create rolebinding "${NS}-edit" --clusterrole=edit --user="$OID" -n "$NS" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    note "rolebinding in $NS only"
  else
    note "!! could not resolve $UPN in Entra — rolebinding skipped"
  fi

  i=$((i+1))
done

say "Done. Now run ./3-cards.sh"
echo "Reminder: leave at least an hour before anyone requests a token (AADSTS70021)."
