#!/bin/bash

set -e

KEY_PATH="${HOME}/.ssh/id_ed25519"
KEY_COMMENT="Ansible Controller Deployment User"

echo "Generating SSH key pair..."

ssh-keygen -t ed25519 -C "${KEY_COMMENT}" -f "${KEY_PATH}" -N ""

echo "SSH key generated successfully:"
echo "  Public key:  ${KEY_PATH}.pub"
echo "  Private key: ${KEY_PATH}"
echo "  Comment:     ${KEY_COMMENT}"
