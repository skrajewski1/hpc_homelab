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


# Directory to store client IP fragments
mkdir -p /home/ec2-user/clients_ip_fragments

# Wait until all expected client files arrive (adjust count if needed)
EXPECTED_CLIENTS=${EXPECTED_CLIENTS:-1}
RECEIVED=0
TIMEOUT=300
TIMER=0

while [ $RECEIVED -lt $EXPECTED_CLIENTS ] && [ $TIMER -lt $TIMEOUT ]; do
  RECEIVED=$(ls /home/ec2-user/clients_ip_fragments/*.json 2>/dev/null | wc -l)
  echo "Waiting for clients to report in... ($RECEIVED/$EXPECTED_CLIENTS)" >> /tmp/setup.log
  sleep 5
  ((TIMER+=5))
done

# Install Ansible
sudo amazon-linux-extras install -y ansible2 >> /tmp/setup.log 2>&1

# Install jq for JSON processing
sudo yum install -y jq >> /tmp/setup.log 2>&1

# Merge all client IPs into a single JSON
jq -s 'reduce .[] as $item ({}; . * $item)' /home/ec2-user/clients_ip_fragments/*.json > /home/ec2-user/clients.json

# Generate hosts.ini for Ansible
mkdir -p /home/ec2-user/ansible/inventory

SM_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

{
  echo "[head]"
  echo "sm ansible_host=${SM_PRIVATE_IP}"

  echo ""
  echo "[compute]"
  jq -r 'to_entries[] | "\(.key) ansible_host=\(.value)"' /home/ec2-user/clients.json

  echo ""
  echo "[all:vars]"
  echo "ansible_user=ec2-user"
  echo "ansible_ssh_private_key_file=/home/ec2-user/hpc.pem"
} > /home/ec2-user/ansible/inventory/hosts.ini


echo "SM setup completed" >> /tmp/setup.log 2>&1