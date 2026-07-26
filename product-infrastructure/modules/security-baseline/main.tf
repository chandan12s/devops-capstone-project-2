resource "aws_security_group" "k8s" {
  name        = "${var.environment}-k8s-sg"
  description = "Security group for Kubernetes node"
  vpc_id      = var.vpc_id

  # SSH — only from your IP
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Kubernetes API server — only from your IP
  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # NodePort range — for accessing apps deployed in K8s
  ingress {
    description = "Kubernetes NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # HTTP — for app access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # All outbound allowed — needed for apt, Docker Hub, etc.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-k8s-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
