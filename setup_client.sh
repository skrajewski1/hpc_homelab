#!/bin/bash
# script: setup_client.sh

# Parameters should be passed as environment variables
# CLIENT_NUM: The client number
# SM_IP: The IP address of the SM instance

LOG="/tmp/setup.log"
log() {
  echo "$(date +'%F %T') $1" >> "$LOG"
}

log "Starting Client setup script for client $CLIENT_NUM"

# Check required parameters
if [ -z "$CLIENT_NUM" ] || [ -z "$SM_IP" ]; then
  log "Error: Required parameters CLIENT_NUM and SM_IP must be set"
  exit 1
fi

# Update system packages
sudo yum update -y >> "$LOG" 2>&1
sudo yum install -y python3 >> "$LOG" 2>&1

# Install Ansible
sudo amazon-linux-extras install -y ansible2 >> "$LOG" 2>&1

# Create ansible user
sudo useradd -m ansible >> "$LOG" 2>&1
echo "ansible:ansible" | sudo chpasswd >> "$LOG" 2>&1
echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers >> "$LOG" 2>&1

# Create config file
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "client IP: $PUBLIC_IP" | sudo tee /etc/config >> "$LOG" 2>&1
echo "client hostname: client-$CLIENT_NUM" | sudo tee -a /etc/config >> "$LOG" 2>&1
echo "sm IP: $SM_IP" | sudo tee -a /etc/config >> "$LOG" 2>&1
echo "sm hostname: sm" | sudo tee -a /etc/config >> "$LOG" 2>&1

# Set hostname
sudo hostnamectl set-hostname client-$CLIENT_NUM >> "$LOG" 2>&1

# Generate JSON fragment with my name and private IP
MY_NAME="client-${CLIENT_NUM}"
MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "{\"${MY_NAME}\": \"${MY_IP}\"}" > /tmp/${MY_NAME}.json

# Copy to SM node (check if private key exists)
KEY_PATH="/home/ec2-user/hpc.pem"
if [ ! -f "$KEY_PATH" ]; then
  log "Error: Private key $KEY_PATH not found"
  exit 1
fi

scp -o StrictHostKeyChecking=no -i "$KEY_PATH" /tmp/${MY_NAME}.json ec2-user@${SM_IP}:/home/ec2-user/clients_ip_fragments/

log "Client $CLIENT_NUM setup completed"
