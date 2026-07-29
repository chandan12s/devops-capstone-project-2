#!/bin/bash
# Fetches secrets from Vault and creates/updates K8s secret
# Usage: inject-secrets.sh <environment>

set -e

ENVIRONMENT=${1:-dev}
NAMESPACE="analytics"
VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

echo "=== Fetching secrets from Vault for: ${ENVIRONMENT} ==="

# Fetch secrets from Vault
DB_PASSWORD=$(vault kv get -field=db-password secret/analytics/${ENVIRONMENT})
API_SECRET=$(vault kv get -field=api-secret-key secret/analytics/${ENVIRONMENT})

# Base64 encode for K8s secret
DB_PASSWORD_B64=$(echo -n "${DB_PASSWORD}" | base64)
API_SECRET_B64=$(echo -n "${API_SECRET}" | base64)

# Apply to Kubernetes — no secret values ever touch Git
kubectl apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: analytics-secrets
  namespace: ${NAMESPACE}
  labels:
    app: analytics-platform
    environment: ${ENVIRONMENT}
    managed-by: vault
type: Opaque
data:
  db-password: ${DB_PASSWORD_B64}
  api-secret-key: ${API_SECRET_B64}
YAML

echo "=== Secrets injected into K8s from Vault ==="
echo "Secret names stored (values never logged):"
kubectl get secret analytics-secrets -n ${NAMESPACE} \
  -o jsonpath='{.data}' | python3 -c \
  "import sys,json; [print(k) for k in json.load(sys.stdin)]"