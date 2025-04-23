#!/bin/bash
# script: setup_client.sh

# Parameters should be passed as environment variables
# CLIENT_NUM: The client number
# SM_IP: The IP address of the SM instance

echo "Starting Client setup script for client $CLIENT_NUM" > /tmp/setup.log

# Check required parameters
if [ -z "$CLIENT_NUM" ] || [ -z "$SM_IP" ]; then
  echo "Error: Required parameters CLIENT_NUM and SM_IP must be set" | tee -a /tmp/setup.log
  exit 1
fi

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
echo "client IP: $PUBLIC_IP" | sudo tee /etc/config >> /tmp/setup.log 2>&1
echo "client hostname: client-$CLIENT_NUM" | sudo tee -a /etc/config >> /tmp/setup.log 2>&1
echo "sm IP: $SM_IP" | sudo tee -a /etc/config >> /tmp/setup.log 2>&1
echo "sm hostname: sm" | sudo tee -a /etc/config >> /tmp/setup.log 2>&1

# Set hostname
sudo hostnamectl set-hostname client-$CLIENT_NUM >> /tmp/setup.log 2>&1

echo "Client $CLIENT_NUM setup completed" >> /tmp/setup.log 2>&1