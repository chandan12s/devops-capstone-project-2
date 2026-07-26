output "k8s_node_public_ip" {
  description = "Public IP of the Kubernetes node — use this to SSH and for kubectl"
  value       = module.k8s_node.public_ip
}

output "k8s_node_instance_id" {
  description = "EC2 instance ID"
  value       = module.k8s_node.instance_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/devops-capstone-key2.pem ubuntu@${module.k8s_node.public_ip}"
}
