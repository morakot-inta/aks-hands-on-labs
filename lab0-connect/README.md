# Lab 0 — Get connected · 15 minutes

Sign in, point `kubectl` at the training cluster, and land in your own namespace.

**Raise your hand during this lab if anything fails.** Not at 14:35, when Lab 1 has started.

---

## 1. Sign in

```bash
az login
```

A browser window opens. Sign in with your organisation account.

```bash
az account show --output table
```

The subscription name should be the training one. If it is not:

```bash
az account set --subscription "<SUBSCRIPTION-NAME>"
```

## 2. Point kubectl at the cluster

```bash
az aks get-credentials --resource-group <RESOURCE-GROUP> --name <CLUSTER>
```

```bash
kubectl get nodes
```

You should see the cluster's nodes, all `Ready`.

> **Times out?** You are probably not on the corporate network. Connect to the VPN and try
> again.

## 3. Move into your own namespace

```bash
kubectl config set-context --current --namespace=<NAMESPACE>
```

---

## Done when

```bash
kubectl get pods
```

prints:

```
No resources found in <NAMESPACE> namespace.
```

**An empty list is the correct answer.** It means you are connected, and pointed at a
namespace that is yours alone — nothing you do for the rest of the afternoon can affect
anyone else.
