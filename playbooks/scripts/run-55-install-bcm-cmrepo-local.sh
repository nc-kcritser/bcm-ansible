#!/bin/bash
# Wrapper for 55-install-bcm-cmrepo-local.yaml
# Local repository installation method

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="${PLAYBOOK_DIR}/inventory/localhost"

echo "Running BCM Local Repository Installation..."
echo "Inventory: ${INVENTORY}"
echo ""

cd "$PLAYBOOK_DIR"
ansible-playbook 55-install-bcm-cmrepo-local.yaml \
  -i "${INVENTORY}" \
  "$@"