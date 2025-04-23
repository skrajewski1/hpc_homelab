terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Adjust as needed for your region
}

variable "client_count" {
  description = "Number of client machines to provision"
  type        = number
  default     = 1  # Default to 1 client
}

# Create SSH key
resource "tls_private_key" "hpc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_lightsail_key_pair" "hpc_key" {
  name       = "hpc"
  public_key = tls_private_key.hpc_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.hpc_key.private_key_pem
  filename        = "${path.module}/hpc.pem"
  file_permission = "0600"  # Set proper permissions for SSH key
}

# Save public key locally
resource "local_file" "public_key" {
  content  = tls_private_key.hpc_key.public_key_openssh
  filename = "${path.module}/hpc.pem.pub"
}

# SM instance
resource "aws_lightsail_instance" "sm" {
  name              = "sm"
  availability_zone = "us-east-1a"  # Adjust as needed
  blueprint_id      = "amazon_linux_2"
  bundle_id         = "micro_2_0"  # Adjust as needed
  key_pair_name     = aws_lightsail_key_pair.hpc_key.name
}

# Wait for SM instance to be ready before attempting SSH
resource "time_sleep" "wait_for_sm" {
  depends_on = [aws_lightsail_instance.sm]
  create_duration = "60s"
}

# Configure SM instance using remote-exec
resource "null_resource" "setup_sm" {
  depends_on = [time_sleep.wait_for_sm]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.hpc_key.private_key_pem
    host        = aws_lightsail_instance.sm.public_ip_address
    timeout     = "2m"
  }

  # Copy setup script to the instance
  provisioner "file" {
    source      = "${path.module}/setup_sm.sh"
    destination = "/tmp/setup_sm.sh"
  }

  # Execute the setup script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_sm.sh",
      "/tmp/setup_sm.sh",
      "echo 'SM setup completed'"
    ]
  }
}

# Client instances
resource "aws_lightsail_instance" "clients" {
  count             = var.client_count
  name              = "client-${count.index + 1}"
  availability_zone = "us-east-1a"  # Adjust as needed
  blueprint_id      = "amazon_linux_2"
  bundle_id         = "micro_2_0"  # Adjust as needed
  key_pair_name     = aws_lightsail_key_pair.hpc_key.name

  depends_on = [null_resource.setup_sm]  # Ensure SM is fully configured first
}

# Wait for client instances to be ready before attempting SSH
resource "time_sleep" "wait_for_clients" {
  depends_on = [aws_lightsail_instance.clients]
  create_duration = "60s"
}

# Configure client instances using remote-exec
resource "null_resource" "setup_clients" {
  count      = var.client_count
  depends_on = [time_sleep.wait_for_clients]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.hpc_key.private_key_pem
    host        = aws_lightsail_instance.clients[count.index].public_ip_address
    timeout     = "2m"
  }

  # Copy setup script to the instance
  provisioner "file" {
    source      = "${path.module}/setup_client.sh"
    destination = "/tmp/setup_client.sh"
  }

  # Execute the setup script with required parameters
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_client.sh",
      "CLIENT_NUM=${count.index + 1} SM_IP=${aws_lightsail_instance.sm.public_ip_address} /tmp/setup_client.sh",
      "echo 'Client ${count.index + 1} setup completed'"
    ]
  }
}

output "sm_public_ip" {
  value = aws_lightsail_instance.sm.public_ip_address
}

output "sm_ssh_command" {
  value = "ssh -i ${path.module}/hpc.pem ec2-user@${aws_lightsail_instance.sm.public_ip_address}"
}

output "client_public_ips" {
  value = [for instance in aws_lightsail_instance.clients : instance.public_ip_address]
}

output "client_ssh_commands" {
  value = [for i in range(var.client_count) : "ssh -i ${path.module}/hpc.pem ec2-user@${aws_lightsail_instance.clients[i].public_ip_address}"]
}