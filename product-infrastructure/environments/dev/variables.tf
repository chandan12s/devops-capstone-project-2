variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "my_ip_cidr" {
  description = "Your local IP in CIDR notation for SSH access"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  description = "EC2 instance type for K8s node"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "AWS key pair name (without .pem)"
  type        = string
  default     = "devops-capstone-key2"
}

variable "use_spot" {
  type    = bool
  default = false
}

variable "spot_max_price" {
  type    = string
  default = "0.0208"
}
