# Lab 3 — Wire up Workload Identity · 45 minutes

Your pod is going to read and write files in Azure Storage **with no access key, no
connection string and no SAS token** — none of which appear anywhere in your manifest or in
the application code.

The hardest lab, because **when you get it wrong nothing errors.** The pod starts normally
and only the storage call fails.

---

## 1. Create the ServiceAccount

Put your `<CLIENT-ID>` into `serviceaccount.yaml`, then:

```bash
kubectl apply -f serviceaccount.yaml
```

## 2. Three changes to your Deployment

**A — run the pod as that ServiceAccount:**

```yaml
    spec:
      serviceAccountName: orders-api
```

**B — label the POD TEMPLATE, not the ServiceAccount:**

```yaml
    metadata:
      labels:
        app: orders-api
        azure.workload.identity/use: "true"
```

**C — tell the app which storage account to use:**

```yaml
        env:
        - name: STORAGE_ACCOUNT
          value: "<STORAGE-ACCOUNT>"
        - name: NAMESPACE
          value: "<NAMESPACE>"
```

```bash
kubectl apply -f deployment.yaml
```

## 3. Work through it in order

Three endpoints, on purpose — each one rules out a different problem.

```bash
POD=$(kubectl get pod -l app=orders-api -o jsonpath='{.items[0].metadata.name}')

# a) does this pod have an identity at all? (no storage involved)
kubectl exec $POD -- curl -s localhost:8080/whoami

# b) can that identity SEE the container?
kubectl exec $POD -- curl -s localhost:8080/storage

# c) can it READ a file?
kubectl exec $POD -- curl -s localhost:8080/storage/read?name=hello.txt

# d) can it WRITE one?
kubectl exec $POD -- curl -s -X POST localhost:8080/storage/write
```

Step (d) prints the name of the file it created. Read it back:

```bash
kubectl exec $POD -- curl -s "localhost:8080/storage/read?name=<the-name-it-printed>"
```

---

## Done when

You have **written a file and read it back**, and there is no key, no connection string and
no SAS token anywhere in your Deployment.

Look at the manifest you just applied. The only thing in it that relates to Azure is a
client ID — which is not a secret, and is safe to commit.

---

## When it does not work

The three endpoints separate the two failures that look identical from the outside:

| What you see | What it means | Fix |
|---|---|---|
| `/whoami` fails | The pod has **no identity** | The pod-template label. Nine times out of ten this is it — the annotation on the ServiceAccount feels like it should be enough, and it is not |
| `/whoami` works but `/storage` returns 403 | The pod **has** an identity, but it is not allowed to touch the container | A role assignment problem, not a Kubernetes one. Tell the trainer |
| `STORAGE_ACCOUNT is not set` | Change **C** is missing | Add the `env` block |

```bash
# the label must be on the POD, not just the Deployment
kubectl get pod -l app=orders-api -o jsonpath='{.items[0].metadata.labels}' | tr ',' '\n'

# the projected token only exists if the label is set
kubectl exec $POD -- ls /var/run/secrets/azure/tokens/
```
