#!/bin/bash
# Generate SSH keypair for Ansible to use with lab nodes
set -e

KEY_DIR="$(cd "$(dirname "$0")/../ansible/keys" && pwd 2>/dev/null || echo "$(dirname "$0")/../ansible/keys")"
KEY_FILE="${KEY_DIR}/lab_node"

mkdir -p "${KEY_DIR}"

if [ -f "${KEY_FILE}" ]; then
    echo "SSH keypair already exists at ${KEY_FILE}"
else
    echo "Generating SSH keypair..."
    ssh-keygen -t ed25519 -f "${KEY_FILE}" -N "" -C "ansible@lab"
    chmod 600 "${KEY_FILE}"
    chmod 644 "${KEY_FILE}.pub"
    echo "SSH keypair generated at ${KEY_FILE}"
fi
