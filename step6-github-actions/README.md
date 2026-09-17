# Deploying from GitHub Actions

Demonstrated in the session rather than practised — but this is the file, ready to copy.

## The one thing worth noticing

```yaml
permissions:
  id-token: write
```

That is the same mechanism you wired up in **Lab 3**. A workload proves who it is and is
handed a short-lived token, so no password or service-principal secret is stored anywhere.
In Lab 3 the workload was a pod; here it is a GitHub workflow. Same idea twice.

## Where it runs matters

Today's training cluster has a **public** API server, so a GitHub-hosted runner can reach it.
**Your real cluster will not.**

| | GitHub-hosted runner | Self-hosted runner, inside your network |
|---|---|---|
| Reaching a private API server | Cannot — no route in, and GitHub's address ranges are too broad to allow | Normal internal traffic; nothing opened to the internet |
| Use it for | Build, test, push the image | Anything running `kubectl` against the cluster |

Most teams end up splitting one workflow across both: build on GitHub-hosted, deploy on
self-hosted.
