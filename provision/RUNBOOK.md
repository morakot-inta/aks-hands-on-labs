# Building the lab environment — copy and paste

For the platform team. Every block below is meant to be pasted into
**[Azure Cloud Shell](https://shell.azure.com)** (Bash) in order.

Cloud Shell is the easiest place to run this: `az` and `kubectl` are already there and
always current, so the `azure-cli 2.86.0` requirement in Step 2 takes care of itself.

Two steps need files from this repository — building the image in Step 4, and the
deliberately broken manifest in Step 9. Clone it first and stay in the root:

```bash
git clone <this repository> && cd <repository>
```

---

## Step 0 · Set your values

**Edit these, then paste the whole block.** Everything after this uses them.

```bash
SUBSCRIPTION="00000000-0000-0000-0000-000000000000"
RG="rg-aks-training"
LOCATION="southeastasia"
CLUSTER="aks-training"
ACR="acrtraining"                 # no .azurecr.io
KEYVAULT="kv-aks-training"
STORAGE="staktraining"            # 3-24 chars, lowercase, globally unique
CONTAINER="lab-data"
IDENTITY="id-aks-lab"
GATEWAY_NS="gateway-system"
GATEWAY_NAME="shared-gateway"
DOMAIN="lab.example.com"
SERVICE_ACCOUNT="orders-api"

az account set --subscription "$SUBSCRIPTION"
az account show --query name -o tsv          # confirm this is the right one
```

---

## Step 1 · Check the cluster has the right shape

```bash
az aks show -g "$RG" -n "$CLUSTER" --query '{
  oidc:oidcIssuerProfile.enabled,
  workloadIdentity:securityProfile.workloadIdentity.enabled,
  overlay:networkProfile.networkPluginMode,
  entraRBAC:aadProfile.enableAzureRbac,
  privateCluster:apiServerAccessProfile.enablePrivateCluster,
  istio:serviceMeshProfile.istio.revisions
}' -o yaml
```

What you want to see:

| Field | Expected | If it is wrong |
|---|---|---|
| `oidc`, `workloadIdentity` | `true` | `az aks update -g $RG -n $CLUSTER --enable-oidc-issuer --enable-workload-identity` |
| `overlay` | `overlay` | Cannot be changed after creation. The labs still run; one sentence in Lab 3 about pod addressing stops being true |
| `entraRBAC` | `true` | `az aks update -g $RG -n $CLUSTER --enable-aad --enable-azure-rbac`. **Without this, attendees cannot be confined to their own namespace** |
| `privateCluster` | `false` or null | A private cluster cannot be reached from attendee laptops |
| `istio` | `asm-1-26` or later | `az aks mesh enable -g $RG -n $CLUSTER` |

---

## Step 2 · Turn on the two add-ons the labs need

```bash
az aks enable-addons -g "$RG" -n "$CLUSTER" --addons azure-policy

az aks update -g "$RG" -n "$CLUSTER" --enable-gateway-api
```

Then connect and confirm:

```bash
az aks get-credentials -g "$RG" -n "$CLUSTER" --overwrite-existing
kubectl get gatewayclass                     # expect "istio", ACCEPTED=True
```

---

## Step 3 · Assign the four policies Lab 1 depends on

The add-on on its own enforces nothing. These four are what refuse the deliberately broken
manifest in Lab 1.

```bash
RG_SCOPE=$(az group show -n "$RG" --query id -o tsv)
ACR_LOGIN=$(az acr show -n "$ACR" --query loginServer -o tsv)

pol() { az policy definition list --query "[?displayName=='$1'].id | [0]" -o tsv; }

az policy assignment create --name lab-allowed-images \
  --policy "$(pol 'Kubernetes cluster containers should only use allowed images')" \
  --scope "$RG_SCOPE" \
  --params "{\"effect\":{\"value\":\"deny\"},\"allowedContainerImagesRegex\":{\"value\":\"^${ACR_LOGIN}/.+$\"}}"

az policy assignment create --name lab-resource-limits \
  --policy "$(pol 'Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits')" \
  --scope "$RG_SCOPE" \
  --params '{"effect":{"value":"deny"},"cpuLimit":{"value":"2"},"memoryLimit":{"value":"2Gi"}}'

az policy assignment create --name lab-nonroot \
  --policy "$(pol 'Kubernetes cluster pods and containers should only run with approved user and group IDs')" \
  --scope "$RG_SCOPE" \
  --params '{"effect":{"value":"deny"},"runAsUserRule":{"value":"MustRunAsNonRoot"},"runAsGroupRule":{"value":"RunAsAny"},"supplementalGroupsRule":{"value":"RunAsAny"},"fsGroupRule":{"value":"RunAsAny"}}'

az policy assignment create --name lab-probes \
  --policy "$(pol 'Ensure cluster containers have readiness or liveness probes configured')" \
  --scope "$RG_SCOPE" \
  --params '{"effect":{"value":"deny"},"probes":{"value":["livenessProbe","readinessProbe"]}}'
```

> **Wait 15 to 20 minutes before testing.** Gatekeeper pulls policy on a schedule, so the
> rules do not bite immediately. Checking too early gives a false failure.

---

## Step 4 · Build the image

```bash
# from a clone of this repository
az acr build --registry "$ACR" --image orders-api:v1 sample-app/

# let the cluster pull it without any imagePullSecret
az aks update -g "$RG" -n "$CLUSTER" --attach-acr "$ACR"
```

---

## Step 5 · Key Vault and storage

```bash
# --- Key Vault, and the secret Lab 2 mounts
az keyvault create -n "$KEYVAULT" -g "$RG" -l "$LOCATION" \
  --enable-rbac-authorization true --retention-days 7

# with RBAC authorisation the creator still needs a data-plane role to write secrets
az role assignment create \
  --assignee-object-id "$(az ad signed-in-user show --query id -o tsv)" \
  --assignee-principal-type User \
  --role "Key Vault Secrets Officer" \
  --scope "$(az keyvault show -n "$KEYVAULT" -g "$RG" --query id -o tsv)"

az keyvault secret set --vault-name "$KEYVAULT" -n db-password --value "this-is-not-a-real-password"

# --- Storage, and the file Lab 3 reads
az storage account create -g "$RG" -n "$STORAGE" -l "$LOCATION" \
  --sku Standard_LRS --allow-blob-public-access false

az storage container create --account-name "$STORAGE" -n "$CONTAINER" --auth-mode login

printf 'Hello from Azure Storage.\nYou read this file with no access key.\n' > hello.txt
az storage blob upload --account-name "$STORAGE" -c "$CONTAINER" -n hello.txt \
  -f hello.txt --auth-mode login --overwrite
```

---

## Step 6 · The managed identity the pods will use

```bash
az identity create -g "$RG" -n "$IDENTITY" -l "$LOCATION"

IDENTITY_CLIENT=$(az identity show -g "$RG" -n "$IDENTITY" --query clientId -o tsv)
IDENTITY_PRINCIPAL=$(az identity show -g "$RG" -n "$IDENTITY" --query principalId -o tsv)
echo "client id for the attendee cards: $IDENTITY_CLIENT"

# it reads and writes the container (Contributor — Lab 3 uploads as well as downloads)
az role assignment create --assignee-object-id "$IDENTITY_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)/blobServices/default/containers/$CONTAINER"

# and reads the vault
az role assignment create --assignee-object-id "$IDENTITY_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope "$(az keyvault show -n "$KEYVAULT" -g "$RG" --query id -o tsv)"
```

---

## Step 7 · The shared Gateway for Lab 4

```bash
kubectl create namespace "$GATEWAY_NS" --dry-run=client -o yaml | kubectl apply -f -

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
        from: All
  infrastructure:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
YAML

kubectl -n "$GATEWAY_NS" get gateway "$GATEWAY_NAME"
```

---

## Step 8 · One namespace and one credential per attendee

**Put your attendees here**, `namespace:sign-in`, then paste the whole block.

```bash
ATTENDEES="
alice:alice@example.com
bob:bob@example.com
"

OIDC=$(az aks show -g "$RG" -n "$CLUSTER" --query oidcIssuerProfile.issuerUrl -o tsv)
AKS_ID=$(az aks show -g "$RG" -n "$CLUSTER" --query id -o tsv)

for row in $ATTENDEES; do
  NS="${row%%:*}"; UPN="${row##*:}"
  echo "--- $NS ($UPN)"

  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

  # sequential on purpose: creating these in parallel under one identity returns 409
  az identity federated-credential create \
    --name "fc-$NS" --identity-name "$IDENTITY" -g "$RG" \
    --issuer "$OIDC" \
    --subject "system:serviceaccount:${NS}:${SERVICE_ACCOUNT}" \
    --audience api://AzureADTokenExchange -o none

  # lets them run az aks get-credentials
  az role assignment create --assignee "$UPN" \
    --role "Azure Kubernetes Service Cluster User Role" --scope "$AKS_ID" -o none

  # lets them edit things, in their own namespace only
  az role assignment create --assignee "$UPN" \
    --role "Azure Kubernetes Service RBAC Writer" \
    --scope "${AKS_ID}/namespaces/${NS}" -o none
done
```

> **One managed identity holds at most 20 federated credentials.** For more than 20
> attendees, create a second identity (`IDENTITY="id-aks-lab-2"`, repeat Step 6) and run
> this block again with the remaining names.

> **Run this at least an hour before the session.** A token requested before the credential
> has propagated fails with `AADSTS70021`, and it looks exactly like attendee error.

---

## Step 9 · Prove it works

Do not assume — the two failures that matter are both invisible to a resource listing.

```bash
kubectl create namespace preflight --dry-run=client -o yaml | kubectl apply -f -

# this manifest breaks four rules. It MUST be rejected.
kubectl -n preflight apply -f lab1-deployment/deployment-broken.yaml
```

**If that manifest is accepted, stop.** The policies are not in force, and Lab 1 has no
lesson left in it. Wait longer, or check Step 3.

```bash
# the image is where the labs expect
az acr repository show --name "$ACR" --image orders-api:v1 -o none && echo "image OK"

# the file Lab 3 reads
az storage blob show --account-name "$STORAGE" -c "$CONTAINER" -n hello.txt \
  --auth-mode login -o none && echo "hello.txt OK"

kubectl delete namespace preflight
```

---

## Step 10 · The attendee cards

Every lab refers to these placeholders. One card per attendee.

```bash
echo "RESOURCE-GROUP : $RG"
echo "CLUSTER        : $CLUSTER"
echo "ACR            : $ACR"
echo "KEY-VAULT      : $KEYVAULT"
echo "STORAGE-ACCOUNT: $STORAGE"
echo "CLIENT-ID      : $IDENTITY_CLIENT"
echo "TENANT-ID      : $(az account show --query tenantId -o tsv)"
echo
echo "Per attendee: NAMESPACE = their own name, hostname = <namespace>.$DOMAIN"
```

---

## Afterwards · Tearing it down

```bash
for row in $ATTENDEES; do
  NS="${row%%:*}"
  kubectl delete namespace "$NS" --wait=false
done

kubectl -n "$GATEWAY_NS" delete gateway "$GATEWAY_NAME"
az identity delete -g "$RG" -n "$IDENTITY"
```

Deleting the whole resource group removes everything at once, including the cluster:

```bash
az group delete -n "$RG" --yes --no-wait
```
