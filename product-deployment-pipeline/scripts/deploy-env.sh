#!/bin/bash
# Usage: deploy-env.sh <environment> <image_tag>

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

# Set replicas per environment
case ${ENVIRONMENT} in
  dev)   API_REPLICAS=1 ;;
  stage) API_REPLICAS=2 ;;
  prod)  API_REPLICAS=3 ;;
esac

echo "--- Applying base manifests ---"
kubectl apply -f /mnt/c/Users/shivc/Desktop/enterprise-product-deployment/product-kubernetes/base/namespace.yaml

kubectl apply -f /mnt/c/Users/shivc/Desktop/enterprise-product-deployment/product-kubernetes/base/

echo "--- Applying ${ENVIRONMENT} config overlay ---"
kubectl apply -f \
  /mnt/c/Users/shivc/Desktop/enterprise-product-deployment/product-kubernetes/overlays/${ENVIRONMENT}/configmap-patch.yaml

echo "--- Scaling API to ${API_REPLICAS} replicas for ${ENVIRONMENT} ---"
# Use patch instead of apply for replica changes — avoids selector conflict
kubectl patch deployment analytics-api \
  -n ${NAMESPACE} \
  -p "{\"spec\":{\"replicas\":${API_REPLICAS}}}"

echo "--- Updating image tags to ${IMAGE_TAG} ---"
kubectl set image deployment/analytics-api \
  analytics-api=${DOCKER_USER}/analytics-api:${IMAGE_TAG} \
  -n ${NAMESPACE}

kubectl set image deployment/analytics-processor \
  analytics-processor=${DOCKER_USER}/analytics-processor:${IMAGE_TAG} \
  -n ${NAMESPACE}

echo "--- Waiting for rollout ---"
kubectl rollout status deployment/analytics-api \
  -n ${NAMESPACE} --timeout=120s

kubectl rollout status deployment/analytics-processor \
  -n ${NAMESPACE} --timeout=120s

echo ""
echo "=== Deployment to ${ENVIRONMENT} complete ==="
kubectl get pods -n ${NAMESPACE}
kubectl get deployments -n ${NAMESPACE}