#!/bin/bash
# Wrapper for 55-install-bcm-cmrepo-local.yaml
# Local repository installation method

PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${PLAYBOOK_DIR}/inventory/localhost"

echo "Running BCM Local Repository Installation..."
echo "Inventory: ${INVENTORY}"
echo ""

ansible-playbook "${PLAYBOOK_DIR}/55-install-bcm-cmrepo-local.yaml" \
  -i "${INVENTORY}" \
  "$@"