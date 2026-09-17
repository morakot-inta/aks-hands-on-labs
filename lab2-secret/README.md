# Lab 2 — Mount a secret from Key Vault · 15 minutes

Short lab. The secret arrives as a **file**, not an environment variable — that is the part
that usually means a code change in your own application.

---

## 1. Create the SecretProviderClass

Edit `secretproviderclass.yaml` and fill in your three values, then:

```bash
kubectl apply -f secretproviderclass.yaml
```

## 2. Add a volume to your Deployment

Add these two blocks to the Deployment you fixed in Lab 1 — see `solution/deployment.yaml`
if you want the exact indentation.

```yaml
      volumes:
      - name: secrets
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: orders-api-spc
```

```yaml
        volumeMounts:
        - name: secrets
          mountPath: /mnt/secrets-store
          readOnly: true
```

```bash
kubectl apply -f deployment.yaml
```

## 3. Read it from inside the pod

```bash
POD=$(kubectl get pod -l app=orders-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /mnt/secrets-store/db-password
```

The app also reports on it, without printing the value:

```bash
kubectl exec $POD -- curl -s localhost:8080/secret
```

Before the volume is mounted that returns `503` and tells you what is missing.

---

## Done when

The command above prints the secret value.

**Now ask yourself:** your own application reads its secrets from somewhere today. If it
reads an environment variable, this is a code change — not a big one, but a real one. That
is worth knowing now rather than during a migration.
