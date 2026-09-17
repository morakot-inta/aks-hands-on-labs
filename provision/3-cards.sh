#!/usr/bin/env bash
# 3 — one card per attendee. Print these and hand them out; every lab refers to
#     the placeholders on them.
set -euo pipefail
cd "$(dirname "$0")"; source ./config.sh

TENANT=$(az account show --query tenantId -o tsv)
mkdir -p cards; rm -f cards/*.md

mapfile -t ROWS < <(grep -v '^[[:space:]]*#' attendees.txt | grep -v '^[[:space:]]*$')
i=0
for row in "${ROWS[@]}"; do
  NS="$(echo "${row%%,*}" | tr -d '[:space:]')"
  UPN="$(echo "${row##*,}" | tr -d '[:space:]')"
  n=$(( i / MAX_FIC_PER_IDENTITY ))
  CLIENT_ID=$(az identity show -g "$RG" -n "${IDENTITY_PREFIX}-${n}" --query clientId -o tsv)

  cat > "cards/${NS}.md" <<CARD
# AKS labs — ${NS}

Sign in as **${UPN}**

| Placeholder | Your value |
|---|---|
| \`<NAMESPACE>\` | \`${NS}\` |
| \`<RESOURCE-GROUP>\` | \`${RG}\` |
| \`<CLUSTER>\` | \`${CLUSTER}\` |
| \`<ACR>\` | \`${ACR}\` |
| \`<CLIENT-ID>\` | \`${CLIENT_ID}\` |
| \`<KEY-VAULT>\` | \`${KEYVAULT}\` |
| \`<TENANT-ID>\` | \`${TENANT}\` |
| \`<STORAGE-ACCOUNT>\` | \`${STORAGE}\` |

Your hostname for Lab 4: \`${NS}.${DOMAIN}\`

## Start here

\`\`\`bash
az login
az aks get-credentials --resource-group ${RG} --name ${CLUSTER}
kubectl config set-context --current --namespace=${NS}
kubectl get pods        # "No resources found" is the correct answer
\`\`\`
CARD
  echo "  cards/${NS}.md"
  i=$((i+1))
done
echo
echo "$i cards written. Print them, or paste each one into a chat message to its owner."
