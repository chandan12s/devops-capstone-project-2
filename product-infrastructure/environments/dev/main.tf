terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 — replace BUCKET_NAME after running step 1
  backend "s3" {
    bucket  = "enterprise-deployment-tfstate-204998944371"
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------- VPC + Networking ----------
module "vpc" {
  source      = "../../modules/vpc-networking"
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

# ---------- Security baseline ----------
module "security" {
  source      = "../../modules/security-baseline"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  my_ip_cidr  = var.my_ip_cidr
}

# ---------- Kubernetes node (single EC2) ----------
module "k8s_node" {
  source            = "../../modules/eks-cluster"
  environment       = var.environment
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security.k8s_sg_id
}
