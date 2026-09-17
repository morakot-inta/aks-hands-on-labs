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

| # | What | Why it matters |
|---|---|---|
| 1 | An AKS cluster for training | Everything runs on it |
| 2 | **API server reachable from attendee laptops** | Highest-risk item — see Decision 2 |
| 3 | One namespace per attendee | So nobody can break anyone else's work |
| 4 | Each attendee granted **AKS Cluster User Role** + edit in their namespace | Lab 0 |
| 5 | **ACR attached to the cluster** (`az aks update --attach-acr`) | Every lab; removes the need for an imagePullSecret |
| 6 | The sample image `orders-api:v1` present in that ACR | Labs 1–4 |
| 7 | **Key Vault** with a secret named `db-password`, and the **Secrets Store CSI driver** add-on enabled | Lab 2 |
| 7b | Key Vault access for the managed identity (**Key Vault Secrets User**) | Lab 2 |
| 8 | **Workload Identity + OIDC issuer** enabled, and a managed identity with **one federated credential per attendee namespace** | Lab 3. A single managed identity can hold **at most 20 federated credentials**, so more than 20 attendees needs a second identity. They must be created **sequentially** — concurrent creation under one identity returns 409 — and **well in advance**, because a token requested minutes after creation fails with `AADSTS70021` while it propagates |
| 8b | A **storage account** with a container `lab-data`, one file `hello.txt` in it, and **Storage Blob Data Contributor** granted to the managed identity on that container | Lab 3 reads and writes real files. Contributor, not Reader — the lab uploads as well as downloads |
| 9 | **Istio add-on `asm-1-26`+ AND Managed Gateway API enabled**, with one shared internal Gateway | Lab 4. Gateway API does not work without both |
| 10 | **Azure Policy add-on, baseline in DENY mode** | Lab 1 is built on the manifest actually being rejected. In audit mode the lab has no lesson in it |
| 11 | *(resolved — `curl` ships inside the sample image, so Lab 4 verifies from the attendee's own pod)* | Lab 4 |
| 12 | A printed card per attendee: namespace, resource group, cluster, ACR, client ID, key vault, tenant ID, **storage account** | Every lab refers to these placeholders |

**Verify items 5, 9 and 10 by actually running Labs 1–4 end to end before the day.** Each of
them fails in a way that only shows up when you try.

---

# Part C · Three decisions still open

### Decision 1 · How attendees get the lab files

The repository is private. Options: invite each attendee as a collaborator (they need GitHub
accounts), move it to your own organisation and grant the team, or hand out a ZIP on the
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
