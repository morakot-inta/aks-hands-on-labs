# Provisioning the lab environment

Run by **the platform team**, in their own subscription, before the session.

Five scripts. Run them in order, then run `4-verify.sh` again the morning of the session.

```bash
cp attendees.txt attendees.txt.bak    # then edit attendees.txt
vi config.sh                          # names of your RG, cluster, ACR, vault, storage
./1-shared.sh
./2-attendees.sh
./3-cards.sh
./4-verify.sh
```

| Script | What it does | Re-runnable |
|---|---|---|
| `config.sh` | Names of everything. **Edit this first** | — |
| `attendees.txt` | One line per attendee: `namespace,sign-in` | — |
| `1-shared.sh` | Storage container + `hello.txt`, Key Vault secret, shared Gateway | yes |
| `2-attendees.sh` | Namespace, federated credential, role assignments, per-namespace RoleBinding | yes |
| `3-cards.sh` | Writes `cards/<name>.md` — the values every lab refers to | yes |
| `4-verify.sh` | Proves the environment works, including that Lab 1 actually gets rejected | yes |
| `9-teardown.sh` | Removes namespaces and identities. Leaves cluster, ACR, vault, storage | — |

---

## Three things that will bite you

**Run `2-attendees.sh` at least an hour before the session.** A federated credential takes
time to propagate. A token requested too soon fails with `AADSTS70021: No matching federated
identity record found`, and it looks exactly like an attendee having made a mistake.

**A managed identity holds at most 20 federated credentials.** The script spreads attendees
across `id-aks-lab-0`, `-1`, `-2` … automatically. It also creates them **sequentially** on
purpose — creating them in parallel under one identity returns HTTP 409.

**Azure Policy must be in DENY mode, not audit.** Lab 1 is built entirely on a deliberately
broken manifest being refused. In audit mode it is accepted and the lab has no lesson left
in it. `4-verify.sh` checks this by actually trying to apply the broken manifest.

---

## What is NOT here

The cluster, registry, Key Vault and storage account themselves. Those are created once,
with whatever standards your organisation applies to any other environment. This toolkit fills them.

Building the image is one command, and is also the Step 1 demonstration:

```bash
az acr build --registry <ACR> --image orders-api:v1 ../sample-app   # TypeScript on Bun
```

---

## Prerequisites for whoever runs this

- `az` signed in with rights to create identities and role assignments in the resource group
- `kubectl` already pointed at the cluster (`az aks get-credentials`)
- **bash 4+** — `mapfile` is used. macOS ships bash 3.2; run with `/opt/homebrew/bin/bash`
- Permission to read users from Entra (`az ad user show`), for the per-namespace RoleBinding
