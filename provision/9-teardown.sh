#!/usr/bin/env bash
# 9 — remove everything this toolkit created. Asks first.
set -uo pipefail
cd "$(dirname "$0")"; source ./config.sh

mapfile -t ROWS < <(grep -v '^[[:space:]]*#' attendees.txt | grep -v '^[[:space:]]*$')
echo "This will delete:"
echo "  - ${#ROWS[@]} namespaces and their contents"
echo "  - the managed identities ${IDENTITY_PREFIX}-* and their federated credentials"
echo "  - the shared Gateway in $GATEWAY_NS"
echo
echo "It will NOT delete the cluster, the registry, the key vault or the storage account."
read -r -p "Type the cluster name to confirm: " answer
[ "$answer" = "$CLUSTER" ] || { echo "Cancelled."; exit 1; }

for row in "${ROWS[@]}"; do
  NS="$(echo "${row%%,*}" | tr -d '[:space:]')"
  kubectl delete ns "$NS" --wait=false 2>/dev/null && echo "  deleting namespace $NS"
done
kubectl -n "$GATEWAY_NS" delete gateway "$GATEWAY_NAME" --wait=false 2>/dev/null || true

for id in $(az identity list -g "$RG" --query "[?starts_with(name,'${IDENTITY_PREFIX}')].name" -o tsv); do
  az identity delete -g "$RG" -n "$id" -o none && echo "  deleted identity $id"
done
echo "Done."
