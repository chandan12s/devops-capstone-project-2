variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "stage"
}
variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
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
  default = "t3.small"
}
variable "key_name" {
  type    = string
  default = "devops-capstone-key2"
}
