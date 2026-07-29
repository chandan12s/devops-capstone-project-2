# Enterprise Analytics Platform — DevOps Capstone

## Architecture
- CI/CD: Jenkins (local WSL)
- Builds: Docker Desktop (local)
- Registry: Docker Hub
- IaC: Terraform (local WSL) → AWS
- Orchestration: Kubernetes on 1x t3.small EC2
- State: S3 bucket
- Monitoring: EFK stack inside K8s

## Phases
1. Foundation — CI/CD + Terraform + Kubernetes
2. Enterprise Readiness — Multi-env + Security + Monitoring
3. Scale & Optimization — Templating + DR + Cost
# build test!!
