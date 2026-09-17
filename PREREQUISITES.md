# AKS hands-on labs — prerequisites

Everything that must be true before 14:00 on the day. Three parts: what each attendee does,
what the platform team builds, and three decisions that are still open.

---

# Part A · Each attendee, on their own laptop

## A1 · Tools

| Tool | Needed for | Install |
|---|---|---|
| **Azure CLI** (`az`) 2.60+ | Every lab | Windows `winget install Microsoft.AzureCLI` · macOS `brew install azure-cli` |
| **kubectl** | Every lab | `az aks install-cli` (after the Azure CLI) |
| **A text editor** | Labs 1–4 | VS Code, or whatever you use for YAML |
| **git** | Getting the lab files | Already on most machines. Alternative: download the repo as a ZIP |
| `jq` | One command in Lab 4 | **Optional.** Without it the same check works, just less readable |

**Docker is NOT required.** Nothing is built on your machine — Step 1 is demonstrated, not
practised. This is deliberate: Docker Desktop is the tool most often blocked on a corporate
laptop, and the one with licensing conditions.

> **If your laptop blocks software installation, say so now.** There is a browser-based
> alternative but it has to be arranged in advance.

## A2 · Accounts

| Account | Needed for | Notes |
|---|---|---|
| **Microsoft Entra account in your organisation's tenant** | Every lab | The one you already sign into Azure with |
| **GitHub account** | Getting the lab files | Only if we distribute by repository — see Decision 1 |

## A3 · Azure permissions on your account

| Permission | Why |
|---|---|
| **Reader** on the training subscription | So `az account show` and the portal work |
| **Azure Kubernetes Service Cluster User Role** on the training cluster | This is what makes `az aks get-credentials` work. Without it, Lab 0 stops dead |
| Kubernetes **edit** rights **in your own namespace only** | Labs 1–4. Not cluster-wide — you should not be able to touch anyone else's namespace |

## A4 · Network

| | |
|---|---|
| Reach the cluster's API server | Corporate network or VPN — see Decision 2 |
| Outbound HTTPS (443) to `login.microsoftonline.com`, `management.azure.com`, `*.azmk8s.io` | Sign-in and every `kubectl` call |

## A5 · Prove it before the day

Run these. All must succeed.

```bash
az --version
kubectl version --client
az login
az account show
az aks get-credentials --resource-group <RG> --name <CLUSTER>
kubectl get nodes
```

**Send us the error if any of them fail.** Fixing installations on the day comes out of lab
time, and three hours has no slack in it.

---

# Part B · The platform team, before the day

Every command for this is in [`provision/`](../aks-labs/provision/),
written to be pasted into Azure Cloud Shell in order. What follows is what that runbook does
and why each part matters.

## B1 · The cluster itself

Four flags matter. Getting them wrong means rebuilding, so check before creating.

| Flag | Why |
|---|---|
| `--enable-oidc-issuer --enable-workload-identity` | Lab 3 does not exist without these |
| `--network-plugin azure --network-plugin-mode overlay` | The labs teach that pod addresses do not consume VNet space. On a non-overlay cluster that statement is false |
| `--enable-aad --enable-azure-rbac` | **Easy to miss.** Without Entra integration, a RoleBinding against an Entra object ID authorises nobody, so attendees cannot be confined to their own namespace |
| **Public API server** — `privateCluster: false`, restricted with `--api-server-authorized-ip-ranges` | Attendees connect from their own laptops. **A private cluster cannot be used for this session.** This is a deliberate, documented difference from the production design, which requires a private API server — the deck names the exception out loud so attendees do not build the wrong mental model |

Restrict it rather than leaving it open to the internet — one command, no downside:

```bash
az aks update -g $RG -n $CLUSTER \
  --api-server-authorized-ip-ranges "<office egress IP>/32"
```

Check an existing cluster:

```bash
az aks show -g $RG -n $CLUSTER --query '{oidc:oidcIssuerProfile.enabled,
  workloadIdentity:securityProfile.workloadIdentity.enabled,
  overlay:networkProfile.networkPluginMode, entra:aadProfile.managed,
  private:apiServerAccessProfile.enablePrivateCluster}'
```

## B2 · Features to enable on it

| # | What | Command | For |
|---|---|---|---|
| 1 | Istio add-on, revision **`asm-1-26` or later** | `az aks mesh enable -g $RG -n $CLUSTER` | Lab 4 |
| 2 | **Managed Gateway API** | `az aks update -g $RG -n $CLUSTER --enable-gateway-api` | Lab 4. **Needs `azure-cli` 2.86.0+** — `az upgrade`, or `brew upgrade azure-cli` on a Homebrew install |
| 3 | Azure Policy add-on | `az aks enable-addons -g $RG -n $CLUSTER --addons azure-policy` | Lab 1 |
| 4 | Secrets Store CSI driver | `az aks enable-addons -g $RG -n $CLUSTER --addons azure-keyvault-secrets-provider` | Lab 2 |
| 5 | ACR attached | `az aks update -g $RG -n $CLUSTER --attach-acr $ACR` | Every lab — this is what removes the `imagePullSecret` |

Runbook steps 2 and 3.

Verify 1 and 2 landed:

```bash
kubectl get gatewayclass          # expect "istio" with ACCEPTED=True
```

## B3 · The four policies Lab 1 depends on

The add-on alone enforces nothing. Assign these as **`deny`**, scoped to the resource group:

| Policy | Catches |
|---|---|
| `Kubernetes cluster containers should only use allowed images` | an image that is not from your ACR |
| `Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits` | missing or excessive limits |
| `Kubernetes cluster pods and containers should only run with approved user and group IDs` | running as root |
| `Ensure cluster containers have readiness or liveness probes configured` | missing probes |

Runbook step 3 assigns all four with the right parameters.

> **Gatekeeper syncs on a schedule — allow 15 to 20 minutes** before the rules reject
> anything. Verifying immediately gives a false failure.

## B4 · Supporting resources

| # | What | For |
|---|---|---|
| 1 | **ACR** with `orders-api:v1` — `az acr build --registry $ACR --image orders-api:v1 sample-app/` | Every lab |
| 2 | **Key Vault** with a secret `db-password`, RBAC authorisation on | Lab 2 |
| 3 | **Storage account**, container `lab-data`, one file `hello.txt` | Lab 3 |
| 4 | One shared **Gateway**, internal, in `gateway-system` | Lab 4 |

Runbook steps 4, 5 and 7.

## B5 · Per attendee

| # | What | Note |
|---|---|---|
| 1 | A namespace | |
| 2 | A **federated credential** on a managed identity, subject `system:serviceaccount:<ns>:orders-api` | One identity holds **at most 20**, so more than 20 attendees needs a second. Create them **sequentially** — concurrently under one identity returns 409 — and **at least an hour ahead**, or a token request fails with `AADSTS70021` while it propagates |
| 3 | **Azure Kubernetes Service Cluster User Role** on the cluster | Without it `az aks get-credentials` fails and Lab 0 stops dead |
| 4 | A **RoleBinding** to `edit` in their namespace only | Requires B1's `--enable-aad --enable-azure-rbac` |
| 5 | A printed **card**: namespace, resource group, cluster, ACR, client ID, key vault, tenant ID, storage account | Every lab refers to these placeholders |

Items 1 to 4 are runbook step 8; item 5 is step 10.

The managed identity needs **Storage Blob Data Contributor** on the container (Contributor,
not Reader — Lab 3 uploads as well as downloads) and **Key Vault Secrets User** on the vault.

## B6 · Prove it, do not assume it

Runbook step 9 applies the deliberately broken Lab 1 manifest. **If that manifest is accepted, the
policies are not in force and Lab 1 has no lesson left in it** — which is invisible to any
check that only lists resources.

---

# Part C · Three decisions still open

### Decision 1 · How attendees get the lab files

The repository is private. Options: invite each attendee as a collaborator (they need GitHub
accounts), move it to a Kaopanwa organisation and grant the team, or hand out a ZIP on the
day and skip GitHub entirely for the labs.

### Decision 2 · How laptops reach the API server

A private API server, which the landing zone design requires for real clusters, **cannot be
reached from a laptop**. For the training cluster, either give it a public API server with
authorised IP ranges limited to your organisation's offices, or require every attendee to be on the
corporate network. This has to be settled before the cluster is built.

### Decision 3 · ~~How Lab 4 is verified~~ — closed

The obvious approach, a throwaway `curl` pod, is blocked by the allowed-images policy from
Lab 1. Resolved by installing `curl` in the sample image, so Lab 4 verifies from the
attendee's own pod and no jump box is needed.
