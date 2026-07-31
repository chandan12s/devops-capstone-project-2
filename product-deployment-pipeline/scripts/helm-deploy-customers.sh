#!/bin/bash
# Deploys analytics platform to multiple customer namespaces via Helm
# Usage: helm-deploy-customers.sh <image_tag>

set -e

IMAGE_TAG=${1:-latest}
CHART_PATH=/mnt/c/Users/shivc/Desktop/enterprise-deployment-platform/product-kubernetes/helm/analytics-platform
VALUES_PATH=${CHART_PATH}/customer-values

echo "================================================"
echo "Multi-customer Helm deployment"
echo "Image tag: ${IMAGE_TAG}"
echo "================================================"

CUSTOMERS=(
  acme
  globex
  medcorp
  initech
  umbrella
)

PASS=0
FAIL=0
FAILED_CUSTOMERS=""

create_namespace_for_helm() {
  local CUSTOMER=$1
  local NAMESPACE="customer-${CUSTOMER}"

  kubectl apply -f - << NSEOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: ${CUSTOMER}
    meta.helm.sh/release-namespace: ${NAMESPACE}
NSEOF
}

for CUSTOMER in "${CUSTOMERS[@]}"; do
  NAMESPACE="customer-${CUSTOMER}"
  VALUES_FILE="${VALUES_PATH}/customer-${CUSTOMER}.yaml"

  echo ""
  echo "--- Deploying to customer: ${CUSTOMER} (namespace: ${NAMESPACE}) ---"

  create_namespace_for_helm ${CUSTOMER}

  # Helm upgrade --install
  if helm upgrade --install \
    ${CUSTOMER} \
    ${CHART_PATH} \
    --namespace ${NAMESPACE} \
    --values ${VALUES_FILE} \
    --set global.imageTag=${IMAGE_TAG} \
    --wait \
    --timeout 120s; then
    echo "✓ ${CUSTOMER} deployed successfully"
    PASS=$((PASS + 1))
  else
    echo "✗ ${CUSTOMER} deployment failed"
    FAIL=$((FAIL + 1))
    FAILED_CUSTOMERS="${FAILED_CUSTOMERS} ${CUSTOMER}"
  fi
done

echo ""
echo "================================================"
echo "Deployment summary"
echo "================================================"
echo "Total customers: ${#CUSTOMERS[@]}"
echo "Successful:      ${PASS}"
echo "Failed:          ${FAIL}"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed customers:${FAILED_CUSTOMERS}"
fi

echo ""
echo "=== All customer namespaces ==="
kubectl get namespaces | grep customer

echo ""
echo "=== Helm releases ==="
helm list -A | grep -v "^NAME"

echo ""
echo "=== Pod status across all customers ==="
kubectl get pods -A | grep customer

if [ ${FAIL} -gt 0 ]; then
  exit 1
fi

echo ""
echo "All ${PASS} customer deployments successful"