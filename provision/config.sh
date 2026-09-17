#!/usr/bin/env bash
# Edit this file, then run the numbered scripts in order.
export RG="rg-aks-labs"
export LOCATION="southeastasia"
export CLUSTER="aks-labs"
export ACR="acrakslabs"              # no .azurecr.io
export KEYVAULT="kv-aks-labs"
export STORAGE="stakslabs"           # 3-24 chars, lowercase, globally unique
export CONTAINER="lab-data"
export GATEWAY_NS="gateway-system"
export GATEWAY_NAME="shared-gateway"
export DOMAIN="lab.example.com"
export SERVICE_ACCOUNT="orders-api"      # must match lab3 serviceaccount.yaml

# A managed identity holds AT MOST 20 federated credentials, so attendees are
# spread across as many identities as needed. Identity N is "<prefix>-N".
export IDENTITY_PREFIX="id-aks-lab"
export MAX_FIC_PER_IDENTITY=20
