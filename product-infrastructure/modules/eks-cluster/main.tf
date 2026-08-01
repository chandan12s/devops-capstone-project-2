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

  # Spot instance request — saves ~70% vs on-demand
  # Only enabled when var.use_spot = true
  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        # persistent = spot request recreates if interrupted
        spot_instance_type             = "persistent"
        instance_interruption_behavior = "stop"
        # Max price = on-demand price (never pay more than on-demand)
        max_price = var.spot_max_price
      }
    }
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true

    tags = {
      Name      = "${var.environment}-k8s-root"
      ManagedBy = "terraform"
    }
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1
    echo "=== Bootstrap started ==="
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    apt-get update -y
    apt-get install -y curl wget git unzip
    echo "=== Bootstrap complete ==="
  USERDATA
  )

  tags = {
    Name        = "${var.environment}-k8s-node"
    Environment = var.environment
    Project     = "enterprise-deployment"
    ManagedBy   = "terraform"
    Role        = "kubernetes-single-node"
    SpotEnabled = var.use_spot ? "true" : "false"
  }
}

resource "aws_eip_association" "k8s" {
  instance_id   = aws_instance.k8s_node.id
  allocation_id = aws_eip.k8s.id
}