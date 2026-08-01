# Disaster Recovery — RTO/RPO Documentation

## Recovery Objectives

| Metric | Target | How achieved |
|--------|--------|-------------|
| RTO (Recovery Time Objective) | 4 hours | Blue/Green switch = instant; full infra rebuild via Terraform = ~20min |
| RPO (Recovery Point Objective) | 24 hours | Backup CronJob runs every 6 hours; S3 state versioned |

## Recovery Scenarios

### Scenario 1 — Bad deployment (most common)
**Detection:** Smoke test fails or monitoring alert fires
**Recovery:** Blue/Green rollback
```bash
bash product-deployment-pipeline/scripts/bluegreen-switch.sh blue
```
**RTO:** < 30 seconds (service selector patch is instant)
**RPO:** Zero data loss (stateless API)

### Scenario 2 — EC2 node failure
**Detection:** kubectl commands timeout, monitoring alert
**Recovery steps:**
1. Run `terraform apply` — recreates EC2 with same EIP (~5 min)
2. Run `bash scripts/refresh-kubeconfig.sh` (~2 min)
3. K8s state is lost — redeploy manifests (~5 min)
4. Run `helm-deploy-customers.sh` to restore customer deployments (~10 min)

**Total RTO:** ~22 minutes
**RPO:** Last backup (max 6 hours)

### Scenario 3 — Terraform state corruption
**Detection:** `terraform plan` shows unexpected destroys
**Recovery:**
```bash
# List state versions
aws s3api list-object-versions \
  --bucket enterprise-deployment-tfstate-ACCOUNT_ID \
  --prefix dev/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket enterprise-deployment-tfstate-ACCOUNT_ID \
  --key dev/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.restored
```
**RTO:** < 15 minutes
**RPO:** Last Terraform operation

### Scenario 4 — Full AWS region outage
**Detection:** All EC2 health checks fail
**Recovery:** Re-provision in us-west-2 by changing provider region
**RTO:** ~45 minutes (Terraform apply in new region)
**RPO:** Last backup in S3 (cross-region replication recommended for prod)

## Backup Verification Procedure

Run after every backup job:
```bash
# Trigger manual backup
kubectl create job backup-verify-$(date +%s) \
  --from=cronjob/analytics-data-backup \
  -n analytics

# Verify completion
kubectl wait --for=condition=complete job \
  -l app=analytics-backup \
  -n analytics --timeout=60s

# Check logs
kubectl logs -n analytics \
  -l app=analytics-backup --tail=20
```

## DynamoDB State Lock

Prevents concurrent Terraform operations:
- Table: `enterprise-deployment-tf-locks`
- Auto-released after successful apply
- Force-release if stuck: `terraform force-unlock LOCK_ID`
