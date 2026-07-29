#!/bin/bash
# Usage: deploy-env.sh <environment> <image_tag>
# Example: deploy-env.sh dev 42

set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}
NAMESPACE="analytics"
DOCKER_USER="chandans12"

echo "=== Deploying to environment: ${ENVIRONMENT} (tag: ${IMAGE_TAG}) ==="

# Validate environment
if [[ ! "${ENVIRONMENT}" =~ ^(dev|stage|prod)$ ]]; then
  echo "ERROR: environment must be dev, stage, or prod"
  exit 1
fi

# Apply base manifests
echo "--- Applying base manifests ---"
kubectl apply -f \
  /c/Users/shivc/Desktop/enterprise-deployment-platform/product-kubernetes/base/namespace.yaml

kubectl apply -f \
  /c/Users/shivc/Desktop/enterprise-deployment-platform/product-kubernetes/base/

# Apply environment-specific overlay (patches override base)
echo "--- Applying ${ENVIRONMENT} overlay ---"
kubectl apply -f \
  /c/Users/shivc/Desktop/enterprise-deployment-platform/product-kubernetes/overlays/${ENVIRONMENT}/

# Update image tags to exact build
echo "--- Updating image tags to ${IMAGE_TAG} ---"
kubectl set image deployment/analytics-api \
  analytics-api=${DOCKER_USER}/analytics-api:${IMAGE_TAG} \
  -n ${NAMESPACE}

kubectl set image deployment/analytics-processor \
  analytics-processor=${DOCKER_USER}/analytics-processor:${IMAGE_TAG} \
  -n ${NAMESPACE}

# Wait for rollout
echo "--- Waiting for rollout ---"
kubectl rollout status deployment/analytics-api \
  -n ${NAMESPACE} --timeout=120s

kubectl rollout status deployment/analytics-processor \
  -n ${NAMESPACE} --timeout=120s

echo ""
echo "=== Deployment to ${ENVIRONMENT} complete ==="
kubectl get pods -n ${NAMESPACE}