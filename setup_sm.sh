#!/bin/bash
# script: setup_sm.sh

echo "Starting SM setup script" > /tmp/setup.log

# Update system packages
sudo yum update -y >> /tmp/setup.log 2>&1
sudo yum install -y python3 >> /tmp/setup.log 2>&1

# Install Ansible
sudo amazon-linux-extras install -y ansible2 >> /tmp/setup.log 2>&1

# Create ansible user
sudo useradd -m ansible >> /tmp/setup.log 2>&1
echo "ansible:ansible" | sudo chpasswd >> /tmp/setup.log 2>&1
echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers >> /tmp/setup.log 2>&1

# Create config file
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "sm IP: $PUBLIC_IP" | sudo tee /etc/config >> /tmp/setup.log 2>&1
echo "sm hostname: sm" | sudo tee -a /etc/config >> /tmp/setup.log 2>&1

# Set hostname
sudo hostnamectl set-hostname sm >> /tmp/setup.log 2>&1

echo "SM setup completed" >> /tmp/setup.log 2>&1