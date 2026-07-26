# Elastic IP — keeps the public IP stable across reboots
# Important: kubectl config uses this IP, and it must not change
resource "aws_eip" "k8s" {
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-k8s-eip"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "k8s_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # 20GB root volume — enough for K8s + Docker images + EFK
  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true

    tags = {
      Name      = "${var.environment}-k8s-root"
      ManagedBy = "terraform"
    }
  }

  # Bootstrap script runs on first boot
  # Sets up swap (helps with 2GB RAM) and installs prereqs
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    echo "=== Bootstrap started ==="

    # Swap — important on t3.small (2GB RAM)
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # System update
    apt-get update -y
    apt-get install -y curl wget git unzip

    echo "=== Bootstrap complete. Ready for kubeadm setup. ==="
  USERDATA
  )

  tags = {
    Name        = "${var.environment}-k8s-node"
    Environment = var.environment
    Project     = "enterprise-deployment"
    ManagedBy   = "terraform"
    Role        = "kubernetes-single-node"
  }
}

# Associate Elastic IP with instance
resource "aws_eip_association" "k8s" {
  instance_id   = aws_instance.k8s_node.id
  allocation_id = aws_eip.k8s.id
}
