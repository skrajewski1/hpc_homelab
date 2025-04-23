#!/bin/bash
set -e

INVENTORY_FILE="ansible/inventory/hosts.ini"
mkdir -p "$(dirname "$INVENTORY_FILE")"

SM_IP=$(terraform output -raw sm_public_ip)
CLIENT_IPS=$(terraform output -json client_names_with_ips | jq -r 'to_entries[] | "\(.key) \(.value)"')

echo "[head]" > "$INVENTORY_FILE"
echo "sm ansible_host=${SM_IP}" >> "$INVENTORY_FILE"

echo "" >> "$INVENTORY_FILE"
echo "[compute]" >> "$INVENTORY_FILE"
while read -r NAME IP; do
  echo "${NAME} ansible_host=${IP}" >> "$INVENTORY_FILE"
done <<< "$CLIENT_IPS"

echo "" >> "$INVENTORY_FILE"
echo "[all:vars]" >> "$INVENTORY_FILE"
echo "ansible_user=ec2-user" >> "$INVENTORY_FILE"
echo "ansible_ssh_private_key_file=${PWD}/hpc.pem" >> "$INVENTORY_FILE"
