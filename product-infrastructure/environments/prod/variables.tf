variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "prod"
}
variable "vpc_cidr" {
  type    = string
  # Different CIDR per env — no overlap
  default = "10.2.0.0/16"
}
variable "my_ip_cidr" {
  type = string
}
variable "ami_id" {
  type    = string
  default = "ami-0c7217cdde317cfec"
}
variable "instance_type" {
  type    = string
  # Prod would be larger in real life
  default = "t3.small"
}
variable "key_name" {
  type    = string
  default = "devops-capstone-key2"
}
