# orders-api — the sample application

TypeScript on [Bun](https://bun.sh). One file, two Azure SDK packages, no web framework.
You are meant to be able to read all of it.

| Endpoint | Used in | Behaviour |
|---|---|---|
| `/healthz` | Lab 1 | Always 200 — the liveness probe |
| `/ready` | Lab 1 | Always 200 — the readiness probe |
| `/secret` | Lab 2 | 200 once the Key Vault secret is mounted, 503 with a hint before that. Reports the length, never the value |
| `/whoami` | Lab 3 | Did the pod get an identity at all? No storage involved, so it isolates the first failure |
| `/storage` | Lab 3 | Lists the container. 403 here means the identity works but has no role assignment |
| `/storage/read` | Lab 3 | Downloads a file |
| `/storage/write` | Lab 3 | Uploads one. `GET` or `POST`, whichever is easier to type |

## Four deliberate design choices

**`/ready` does not check the secret or storage.** Lab 1 happens before either is wired up.
If readiness depended on them, the Lab 1 Deployment would never reach `2/2` and the lab
would be unfinishable.

**Three storage endpoints, not one.** `/whoami` fails when the pod has no identity;
`/storage` fails when it has one but no role assignment. From the outside those two look
identical, and separating them is what makes the lab debuggable in 45 minutes.

**No key, anywhere.** There is no access key, connection string or SAS token in the code or
in any manifest. `DefaultAzureCredential` is handed to the SDK and Azure decides the rest.

**`curl` is installed in the image.** Lab 4 verifies the published route from inside the
cluster, and the allowed-images policy from Lab 1 blocks pulling a throwaway curl image — so
the tool travels with the application instead.

## Build and push (platform team, before the session)

```bash
az acr build --registry <ACR> --image orders-api:v1 .
```

That builds inside ACR, so nothing is built on the machine running the command — which is
also what the Step 1 demonstration shows.

## Run it locally

```bash
bun install
bun run index.ts
curl localhost:8080/healthz
```

The storage endpoints need `STORAGE_ACCOUNT` set and an `az login` first. `/whoami` will
succeed locally using your Azure CLI sign-in — in the cluster the same code path uses the
pod's federated token instead, which is the point.
