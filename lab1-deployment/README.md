# Lab 1 — Write a Deployment the cluster accepts · 45 minutes

`deployment-broken.yaml` breaks **four** of the cluster's rules. Your job is to find them by
being refused, not by being told.

---

## 1. Try it

```bash
kubectl apply -f deployment-broken.yaml
```

It is rejected. **Read the message.** It names the policy that refused it, which is a strong
hint about what to change.

## 2. Fix one thing, apply again

Edit the file, re-apply, read the next rejection. Four rejections, four fixes.

<details>
<summary>Hint — what the four rules are about (open only if stuck for 10 minutes)</summary>

1. Where the image may come from
2. Which user the container runs as
3. How much CPU and memory the container is asking for, and is allowed
4. How the cluster knows the container is alive and ready

</details>

## 3. Watch it come up

```bash
kubectl get deploy orders-api -w
```

---

## Done when

```bash
kubectl get deploy orders-api
```

shows:

```
NAME         READY   UP-TO-DATE   AVAILABLE
orders-api   2/2     2            2
```

**Finished early?** Break it again a different way and see which rule catches it. Removing
`runAsNonRoot` and removing the memory limit fail differently — worth seeing both.

**Brought your own manifest?** Use it instead of ours. It is a better use of the 45 minutes,
and whatever it is missing is real work you would otherwise find out about later.
