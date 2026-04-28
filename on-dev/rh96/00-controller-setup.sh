#!/bin/bash
set -e  # Exit on any error

echo "=== Setting up EL Control Node for BCM Ansible Installation ==="

if ! grep -qi "rocky\|rhel" /etc/os-release; then
  echo "Error: This script is for Rocky or RHEL 9.x only"
  exit 1
fi

# 1. Install EPEL and enable CRB repository
echo "Installing EPEL and enabling CRB..."
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
if grep -qi rocky /etc/os-release; then
  dnf config-manager --set-enabled crb
else
  subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms
fi

# 2. Install Ansible if not already installed
echo "Installing Ansible..."
dnf install -y ansible-core python3-pip

# 2.1 Upgrade Ansible Core to 2.15+
echo "Updating Ansible Core to 2.15.x or higher ..."
pip install --upgrade ansible-core

# 3. Install required Python packages for the installer collection
echo "Installing required Python packages..."
pip3 install jmespath xmltodict netaddr

# 4. Install the BCM installer collection
echo "Installing brightcomputing.installer110 collection..."
ansible-galaxy collection install brightcomputing.installer110

echo "Installing Support Collections"
ansible-galaxy collection install community.general
ansible-galaxy collection install community.crypto
ansible-galaxy collection install community.mysql
ansible-galaxy collection install ansible.posix

# 5. Verify installation
echo ""
echo "=== Installed Collections ==="
ansible-galaxy collection list

echo ""
echo "=== Ansible Version ==="
ansible --version

echo ""
echo "=== Python Packages ==="
pip3 list | grep -E 'jmespath|xmltodict|netaddr'

echo ""
echo "✓ Control node setup complete!"
echo ""
echo "Next steps:"
echo "1. Build your RHEL 9.6/9.7 target machine"
echo "2. Prepare it with MariaDB, Python3, disabled SELinux"
echo "3. Determine how you'll provide BCM packages (network/local/dvd)"
echo "4. Create your BCM installation playbook"

