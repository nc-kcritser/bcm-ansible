#!/bin/bash
# Wrapper for 54-install-bcm-dvd.yaml
# Overrides post_install_default_image_archive to point to /root location
# since BCM role vars take precedence over group_vars

PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${PLAYBOOK_DIR}/inventory/localhost"
IMAGE_PATH="/root/RHEL9u6.tar.gz"

echo "Running BCM DVD Installation..."
echo "Inventory: ${INVENTORY}"
echo "Image: ${IMAGE_PATH}"
echo ""

ansible-playbook "${PLAYBOOK_DIR}/54-install-bcm-dvd.yaml" \
  -i "${INVENTORY}" \
  -e "post_install_default_image_archive=${IMAGE_PATH}" \
  "$@"