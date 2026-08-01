variable "environment" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "use_spot" {
  description = "Use spot instance for cost savings (~70% cheaper)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Max spot price — on-demand price so we never overpay"
  type        = string
  default     = "0.0208"
}