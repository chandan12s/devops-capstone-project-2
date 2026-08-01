# Cost Optimization Report
## Enterprise Analytics Platform — Dev Environment

## Current Costs (On-Demand)

| Resource | Type | Cost/hr | Cost/month |
|----------|------|---------|------------|
| EC2 (K8s node) | t3.small on-demand | $0.0208 | $15.17 |
| EBS (20GB gp2) | Storage | $0.0027 | $2.00 |
| Elastic IP | EIP (attached) | $0.00 | $0.00 |
| S3 (state files) | < 1MB | ~$0.00 | ~$0.00 |
| DynamoDB (locks) | Pay per request | ~$0.00 | ~$0.00 |
| **Total** | | **$0.0235** | **$17.17** |

## After Spot Instance Optimization

| Resource | Type | Cost/hr | Cost/month | Saving |
|----------|------|---------|------------|--------|
| EC2 (K8s node) | t3.small spot | ~$0.007 | ~$5.10 | 66% |
| EBS (20GB gp2) | Storage | $0.0027 | $2.00 | 0% |
| Elastic IP | EIP (attached) | $0.00 | $0.00 | 0% |
| **Total** | | **~$0.010** | **~$7.10** | **59%** |

## Kubernetes HPA Autoscaling

API deployment configured with HPA:
- Min replicas: 1
- Max replicas: 3
- Scale up when CPU > 50%
- Scale down after 60s of low load

Effect: During off-peak hours (nights/weekends), API scales to 1 replica
saving memory and CPU headroom for other workloads.

## Additional Recommendations

| Optimization | Estimated Saving | Effort |
|-------------|-----------------|--------|
| Spot instance for dev/stage | 66% EC2 cost | Low |
| Stop EC2 nights + weekends | 70% EC2 cost | Low (already doing this) |
| Right-size to t3.micro if load allows | 50% EC2 cost | Low |
| S3 lifecycle rules (delete old state) | Negligible | Low |
| Reserved instance (1yr) for prod | 40% EC2 cost | Medium |

## Terraform Spot Instance Usage

To enable spot for dev:
```bash
# In terraform.tfvars
echo "use_spot = true" >> \
  product-infrastructure/environments/dev/terraform.tfvars
terraform apply -auto-approve
```

To disable (switch back to on-demand):
```bash
sed -i '/use_spot/d' \
  product-infrastructure/environments/dev/terraform.tfvars
terraform apply -auto-approve
```
