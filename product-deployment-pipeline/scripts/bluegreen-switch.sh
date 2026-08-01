#!/bin/bash
# Blue/Green traffic switcher
# Usage: bluegreen-switch.sh <blue|green>
# Example: bluegreen-switch.sh green   (switch traffic to green)
#          bluegreen-switch.sh blue    (rollback to blue)

set -e

TARGET=${1}
NAMESPACE="analytics"
SERVICE="analytics-api-bluegreen"

if [[ ! "${TARGET}" =~ ^(blue|green)$ ]]; then
  echo "Usage: bluegreen-switch.sh <blue|green>"
  exit 1
fi

echo "================================================"
echo "Blue/Green Traffic Switch"
echo "Target slot: ${TARGET}"
echo "================================================"

# Get current active slot
CURRENT=$(kubectl get service ${SERVICE} \
  -n ${NAMESPACE} \
  -o jsonpath='{.spec.selector.slot}')

echo "Current active slot: ${CURRENT}"
echo "Switching to: ${TARGET}"

if [ "${CURRENT}" = "${TARGET}" ]; then
  echo "Already on ${TARGET} — no switch needed"
  exit 0
fi

# Verify target deployment is healthy before switching
echo ""
echo "=== Verifying ${TARGET} deployment is Ready ==="
READY=$(kubectl get deployment analytics-api-${TARGET} \
  -n ${NAMESPACE} \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "${READY}" = "" ] || [ "${READY}" = "0" ]; then
  echo "ERROR: ${TARGET} deployment has no ready replicas"
  echo "Cannot switch traffic to an unhealthy deployment"
  echo "Run: kubectl get pods -n ${NAMESPACE} -l slot=${TARGET}"
  exit 1
fi

echo "${TARGET} has ${READY} ready replica(s) — proceeding"

# Switch the service selector
kubectl patch service ${SERVICE} \
  -n ${NAMESPACE} \
  -p "{\"spec\":{\"selector\":{\"app\":\"analytics-api\",\"slot\":\"${TARGET}\"}}}"

# Update annotation to track active slot
kubectl annotate service ${SERVICE} \
  -n ${NAMESPACE} \
  deployment.kubernetes.io/active-slot=${TARGET} \
  --overwrite

echo ""
echo "=== Switch complete ==="
echo "Traffic now routing to: ${TARGET}"
echo ""

# Verify the switch worked
echo "=== Service selector after switch ==="
kubectl get service ${SERVICE} \
  -n ${NAMESPACE} \
  -o jsonpath='{.spec.selector}' | python3 -m json.tool

echo ""
echo "=== Pod receiving traffic ==="
kubectl get pods \
  -n ${NAMESPACE} \
  -l app=analytics-api,slot=${TARGET} \
  -o wide

echo ""
echo "=== Quick health check on new active slot ==="
K8S_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

sleep 3
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout 5 \
  http://${K8S_IP}:30082/health 2>/dev/null || echo "unreachable")

echo "Health check via NodePort 30082: ${HTTP}"

if [ "${HTTP}" = "200" ]; then
  echo "✓ ${TARGET} slot is healthy and serving traffic"
else
  echo "✗ Health check failed — consider rolling back"
  echo "  Run: bash bluegreen-switch.sh ${CURRENT}"
fi

# Log the switch for audit trail
echo ""
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${TIMESTAMP} | switched from ${CURRENT} to ${TARGET}" >> \
  /tmp/bluegreen-audit.log

echo "Audit log entry written"