variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "my_ip_cidr" {
  description = "Your IP in CIDR — restricts SSH and K8s API access"
  type        = string
}
