# Enterprise Analytics Product Deployment Platform

> A real-world DevOps capstone project simulating how an enterprise company automates the deployment of a self-hosted analytics product across 100+ customer environments — with production-grade CI/CD, security, observability, and disaster recovery.

---

## Problem Statement

An enterprise company sells a data-intensive analytics platform that customers deploy in their own environments (on-premise / self-hosted). As the customer base grew to 100+, the operations team faced compounding problems:

- **Inconsistent deployments** — each customer environment was configured slightly differently, making support difficult and time-consuming
- **High support costs** — environment-specific issues consumed engineering time that should have gone to product development
- **Slow time-to-value** — onboarding a new customer took weeks instead of days due to manual deployment steps
- **No audit trail** — secrets were stored in plain text, environment configurations drifted over time with no way to detect or correct drift
- **No recovery plan** — there were no defined RTO/RPO targets and no documented procedure for handling failures

**Stakeholders affected:** Customer Success Teams, Support Engineers, Product Teams, Security & Compliance, Sales Engineering.

---

## Solution Approach

We built a standardized, automated deployment platform with the following principles:

**1. Everything as Code**
Infrastructure is defined in Terraform, application config in Kubernetes manifests, deployment logic in a Jenkinsfile, and multi-customer templating in Helm charts. Nothing is configured by hand. Any environment can be destroyed and recreated identically from Git.

**2. Security Baked In — Not Bolted On**
Snyk scans dependencies and container images in the CI pipeline before anything is deployed. HashiCorp Vault manages all secrets — no credentials ever touch Git or pipeline logs. Containers run as non-root users. Access is restricted by IP at the security group level.

**3. Multi-Environment by Design**
Dev, stage, and prod are separate Terraform workspaces with isolated S3 state files. Kubernetes overlays apply environment-specific configuration over a common base. The same Helm chart deploys to 10+ customer namespaces with different compliance tiers, feature flags, and resource allocations — zero manual configuration per customer.

**4. Operational Maturity**
Blue/Green deployment enables instant traffic switching with zero downtime and one-command rollback. Automated backup CronJobs run every 6 hours. All 10 failure scenarios from the project spec are covered — 5 with real simulated incidents (with RCA documents) and 5 with detailed runbooks.

---

## Tech Stack

| Category | Tool | Version | Purpose |
|----------|------|---------|---------|
| CI/CD | Jenkins | LTS | Pipeline orchestration |
| Containerisation | Docker Desktop | Latest | Local image builds |
| Registry | Docker Hub | Free tier | Image storage |
| Orchestration | Kubernetes (kubeadm) | 1.29 | Container runtime on AWS |
| IaC | Terraform | >= 1.0 | AWS provisioning |
| Cloud | AWS | us-east-1 | EC2, S3, DynamoDB, VPC |
| Secrets | HashiCorp Vault | Latest | Secret injection |
| Security | Snyk | CLI latest | Dependency + container scanning |
| Monitoring | Elasticsearch | 7.17.9 | Log storage |
| Monitoring | Kibana | 7.17.9 | Log dashboards |
| Monitoring | Fluentd | v1.16 | Log collection |
| Templating | Helm | Latest | Multi-customer K8s deployments |
| Language | Python | 3.11 | Application (Flask API + processor) |
| Web server | Gunicorn | 23.0.0 | Production WSGI server |
| Reverse proxy | Nginx | 1.25 | Frontend webapp |

---

## Dependencies & Setup

### Local machine requirements

| Tool | Install | Verify |
|------|---------|--------|
| WSL2 (Ubuntu 24.04) | Windows features → Virtual Machine Platform | `wsl --version` |
| Docker Desktop | docker.com/products/docker-desktop | `docker ps` |
| Git | Pre-installed on WSL Ubuntu | `git --version` |
| Jenkins | See below | `curl localhost:8080` |
| Terraform | See below | `terraform -version` |
| kubectl | See below | `kubectl version --client` |
| Helm | See below | `helm version` |
| Snyk CLI | See below | `snyk --version` |
| AWS CLI | See below | `aws --version` |

### AWS requirements

- AWS account with free tier or credits
- IAM user with programmatic access and the following permissions:
  `AmazonEC2FullAccess`, `AmazonS3FullAccess`, `AmazonDynamoDBFullAccess`, `AmazonVPCFullAccess`
- Existing EC2 key pair (name: `devops-capstone-key2`)
- Key pair `.pem` file saved to `~/.ssh/devops-capstone-key2.pem` with `chmod 600`

---

## Execution Steps

### Phase 1 — Foundation

#### 1.1 Create S3 backend and provision infrastructure

```bash
# Create S3 bucket for Terraform state
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="enterprise-deployment-tfstate-${AWS_ACCOUNT_ID}"

aws s3api create-bucket --bucket ${BUCKET_NAME} --region us-east-1
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Update bucket name in Terraform backend
sed -i "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" \
  product-infrastructure/environments/dev/main.tf

# Set your current IP and apply
cd product-infrastructure/environments/dev
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "my_ip_cidr = \"${MY_IP}/32\"" > terraform.tfvars

terraform init
terraform plan
terraform apply -auto-approve

# Note the output — you need the EC2 public IP
terraform output
```

#### 1.2 Set up Kubernetes on the EC2

```bash
K8S_IP=$(terraform output -raw k8s_node_public_ip)

# SSH into the EC2 and run kubeadm setup
ssh -i ~/.ssh/devops-capstone-key2.pem ubuntu@${K8S_IP}
```

#### 1.3 Configure local kubectl

```bash
K8S_IP=$(cd product-infrastructure/environments/dev && \
  terraform output -raw k8s_node_public_ip)

mkdir -p ~/.kube
scp -i ~/.ssh/devops-capstone-key2.pem \
  ubuntu@${K8S_IP}:/home/ubuntu/.kube/config \
  ~/.kube/config-enterprise

sed -i "s|https://10\.[0-9]*\.[0-9]*\.[0-9]*:6443|https://${K8S_IP}:6443|g" \
  ~/.kube/config-enterprise

export KUBECONFIG=~/.kube/config-enterprise
echo 'export KUBECONFIG=~/.kube/config-enterprise' >> ~/.bashrc

# Patch the API server TLS certificate to include the public IP
# (run refresh-kubeconfig.sh for the full patching sequence)
bash product-deployment-pipeline/scripts/refresh-kubeconfig.sh

kubectl get nodes  # Should show: Ready
```

#### 1.4 Deploy the application

```bash
cd product-kubernetes

kubectl apply -f base/namespace.yaml
kubectl apply -f base/

# Verify everything is running
kubectl get all -n analytics

# Test the endpoints
curl http://${K8S_IP}:30080/health
curl -X POST http://${K8S_IP}:30080/api/v1/events \
  -H "Content-Type: application/json" \
  -d '{"event_type":"test","payload":{"source":"manual"}}'
curl http://${K8S_IP}:30080/api/v1/stats
```

#### 1.5 Trigger the Jenkins pipeline

```bash
cd ~/enterprise-product-deployment
git add .
git commit -m "ci: trigger first full pipeline run"
git push
# Watch Jenkins at http://localhost:8080
```

---

### Phase 2 — Enterprise Readiness

#### 2.1 Initialise stage and prod Terraform backends

```bash
cd product-infrastructure/environments/stage && terraform init
cd product-infrastructure/environments/prod && terraform init

# Verify separate state files in S3
aws s3 ls s3://${BUCKET_NAME}/ --recursive
```

#### 2.2 Start the EFK monitoring stack

```bash
cd monitoring/local-efk
docker compose up -d

# Wait for Elasticsearch to be healthy
until curl -s http://localhost:9200/_cluster/health | \
  python3 -c "import sys,json; h=json.load(sys.stdin); \
  sys.exit(0 if h['status'] in ['green','yellow'] else 1)" 2>/dev/null; do
  sleep 10
done

echo "Elasticsearch ready. Kibana at http://localhost:5601"
```

#### 2.3 Run the full pipeline with environment selection

In Jenkins, click **Build with Parameters**, select `DEPLOY_ENV = dev`, and click Build.

The pipeline will:
1. Run pytest unit tests
2. Snyk scan dependencies (blocks HIGH/CRITICAL CVEs)
3. Build Docker images tagged with build number
4. Snyk scan the built container image
5. Push images to Docker Hub
6. Fetch secrets from Vault and write to Kubernetes Secret
7. Deploy to Kubernetes with rolling update
8. Run smoke test against the live cluster

#### 2.4 Verify secrets injection

```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='enterprise-vault-token'

# Manually inject secrets for dev
bash product-deployment-pipeline/scripts/inject-secrets.sh dev

# Verify the K8s secret was created (values are base64 — not shown)
kubectl get secret analytics-secrets -n analytics
kubectl describe secret analytics-secrets -n analytics
```

---

### Phase 3 — Scale & Optimization

#### 3.1 Deploy to all customer environments with Helm

```bash
# Lint the chart first
helm lint product-kubernetes/helm/analytics-platform

# Deploy to all 10 customer namespaces
bash product-deployment-pipeline/scripts/helm-deploy-customers.sh latest

# Verify
helm list -A | grep -v "^NAME"
kubectl get pods -A | grep customer
```

#### 3.2 Blue/Green deployment and rollback

```bash
cd product-kubernetes/blue-green

kubectl apply -f deployment-blue.yaml
kubectl apply -f deployment-green.yaml
kubectl apply -f service-bluegreen.yaml

kubectl wait --for=condition=Ready pod \
  -l app=analytics-api,slot=blue -n analytics --timeout=120s
kubectl wait --for=condition=Ready pod \
  -l app=analytics-api,slot=green -n analytics --timeout=120s

# Switch traffic to green
bash product-deployment-pipeline/scripts/bluegreen-switch.sh green

# Verify green is serving
K8S_IP=$(cd product-infrastructure/environments/dev && \
  terraform output -raw k8s_node_public_ip)
curl http://${K8S_IP}:30082/health

# Rollback to blue
bash product-deployment-pipeline/scripts/bluegreen-switch.sh blue
```

#### 3.3 Enable HPA autoscaling

```bash
# Install metrics-server (required for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl wait --for=condition=Ready pod \
  -l k8s-app=metrics-server -n kube-system --timeout=120s

# Apply HPA
kubectl apply -f product-kubernetes/hpa.yaml
kubectl get hpa -n analytics

# Trigger autoscaling with a load test
K8S_IP=$(cd product-infrastructure/environments/dev && \
  terraform output -raw k8s_node_public_ip)

for i in $(seq 1 200); do
  curl -s -X POST http://${K8S_IP}:30080/api/v1/events \
    -H "Content-Type: application/json" \
    -d "{\"event_type\":\"load_test\",\"payload\":{\"n\":${i}}}" \
    > /dev/null
done

# Watch HPA scale up
kubectl get hpa -n analytics
kubectl get pods -n analytics -l app=analytics-api
```

#### 3.4 Run a manual backup

```bash
kubectl apply -f product-kubernetes/backup-cronjob.yaml

# Trigger immediately without waiting for schedule
kubectl create job backup-manual-$(date +%s) \
  --from=cronjob/analytics-data-backup \
  -n analytics

sleep 20
kubectl logs -n analytics -l app=analytics-backup --tail=20
```

---

## Daily Workflow

### Trigger a deployment

```bash
git add . && git commit -m "message" && git push
# Jenkins auto-triggers via GitHub webhook
```

### Update Fluentd with new Vault secrets

```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='enterprise-vault-token'
bash product-deployment-pipeline/scripts/inject-secrets.sh dev
```

---

## Project Structure

```
enterprise-product-deployment/
├── product-deployment-pipeline/
│   ├── Jenkinsfile                        
│   └── scripts/
│       ├── resume-day.sh                    
│       ├── stop-infra.sh                   
│       ├── start-infra.sh                   
│       ├── deploy-env.sh                   
│       ├── helm-deploy-customers.sh        
│       ├── bluegreen-switch.sh              
│       ├── inject-secrets.sh               
│       └── refresh-kubeconfig.sh          
│
├── product-infrastructure/
│   ├── modules/
│   │   ├── vpc-networking/                  
│   │   ├── security-baseline/               
│   │   └── eks-cluster/           
│   └── environments/
│       ├── dev/                           
│       ├── stage/                          
│       └── prod/                           
│
├── product-kubernetes/
│   ├── base/                                
│   ├── overlays/
│   │   ├── dev/                             
│   │   ├── stage/                         
│   │   └── prod/                          
│   ├── blue-green/                         
│   ├── hpa.yaml                            
│   ├── backup-cronjob.yaml                  
│   └── helm/
│       └── analytics-platform/
│           ├── Chart.yaml
│           ├── values.yaml                 
│           ├── templates/                 
│           └── customer-values/           
│
├── product-docker/
│   ├── app/
│   │   ├── api/                           
│   │   ├── data-processor/                 
│   │   └── webapp/                        
│   ├── Dockerfile.api                  
│   └── Dockerfile.processor               
│
├── monitoring/
│   ├── efk/
│   │   └── fluentd-remote.yaml              
│   └── local-efk/
│       ├── docker-compose.yml             
│       └── fluentd/conf/fluent.conf        
│
└── docs/
    ├── architecture.md
    ├── rto-rpo-runbook.md
    ├── evidence/
    └── incident-runbooks/
        ├── RCA-001-k8s-node-failure.md
        ├── RCA-002-registry-outage.md
        ├── RCA-003-config-drift.md
        ├── RCA-004-jenkins-failure.md
        ├── RCA-005-dependency-failure.md
        ├── RCA-006-terraform-state-corruption.md
        ├── RCA-007-eks-control-plane-outage.md
        ├── RCA-008-aws-region-outage.md
        ├── RCA-009-git-repository-corruption.md
        └── RCA-010-certificate-expiration.md
```

---

## Production Targets

| Metric | Target | Achieved |
|--------|--------|----------|
| RTO | 4 hours | 2–5 minutes (simulated incidents) |
| RPO | 24 hours | 6 hours (CronJob backup frequency) |
| Deployment time | — | ~3–5 minutes (git push to live) |
| Environments | 10+ customers | 10 Helm releases configured |
| Security | No HIGH/CRITICAL CVEs | Gunicorn CVE caught and fixed by pipeline |

---

### Name - Chandan S
### Assignment - Devops capstone project - 2
