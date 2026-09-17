# AKS hands-on labs

A half-day, hands-on introduction to running an application on Azure Kubernetes Service —
for developers who already build containers but have not deployed to AKS.

Four labs. In each one you deploy something to a real cluster from your own laptop, in your
own namespace, and something goes wrong on purpose so that you learn why.

| | |
|---|---|
| **Length** | About three hours, including a break |
| **Format** | Hands-on. Attendees deploy; three of the seven steps are demonstrated |
| **You need** | A laptop with the Azure CLI and `kubectl`. **Not Docker** |
| **The platform team needs** | To build the environment first — see [`provision/`](provision/) |

Everything here is copy-and-paste. Placeholders are in `<ANGLE-BRACKETS>` and your values
come from a card handed out at the start.

---

> **Not set up yet?** Read [PREREQUISITES.md](PREREQUISITES.md) first — tools, accounts
> and permissions, and how to check they work.

## Before you start: your five values

Your trainer gives you these on a card. Write them down here — every lab uses them.

| Placeholder used in the labs | Your value |
|---|---|
| `<NAMESPACE>` | your own namespace, usually your first name |
| `<RESOURCE-GROUP>` | |
| `<CLUSTER>` | |
| `<ACR>` | the registry name, without `.azurecr.io` |
| `<CLIENT-ID>` | the managed identity for your namespace (Lab 3) |
| `<STORAGE-ACCOUNT>` | the storage account name, without `.blob.core.windows.net` (Lab 3) |

Wherever you see a placeholder in angle brackets, replace it. Nothing else needs changing.

---

## The labs

| | Lab | Time | You finish when |
|---|---|---|---|
| 0 | [Get connected](lab0-connect/) | 15 min | `kubectl get pods` says *No resources found* |
| 1 | [Write a Deployment the cluster accepts](lab1-deployment/) | 45 min | `kubectl get deploy` shows `READY 2/2` |
| 2 | [Mount a secret from Key Vault](lab2-secret/) | 15 min | you can `cat` the secret inside the pod |
| 3 | [Wire up Workload Identity](lab3-workload-identity/) | 45 min | you write a file to Azure Storage and read it back, with no key anywhere |
| 4 | [Publish it](lab4-publish/) | 20 min | `curl` returns HTTP 200 from your service |

Plus [deploying from GitHub Actions](step6-github-actions/), which is demonstrated rather
than practised.

The application you deploy is in [`sample-app/`](sample-app/) — one readable file, if you
want to see what the endpoints actually do.

Platform engineers: [`provision/`](provision/) builds the whole environment — copy and paste into Azure Cloud Shell.

---

## If you get stuck

Every lab has a `solution/` folder. **Try to finish without it** — in Lab 1 especially, being
refused by the cluster and working out why is the entire point of the exercise.

Raise a hand instead. The trainer is circulating.
