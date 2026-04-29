#!/bin/bash
set -e  # Exit on any error
echo "=== Setting up EL Control Node for BCM 11 Ansible Installation ==="

# Verify OS
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

# 2. Install base system packages
echo "Installing base system packages..."
dnf install -y python3-pip tmux

# 3. Install Python dependencies from prereqs/requirements-pip.txt
echo "Installing Python dependencies from requirements..."
pip3 install -r ../prereqs/requirements-pip.txt

# 4. Install Ansible Collections from prereqs/requirements-collections.yml
echo "Installing Ansible Collections..."
ansible-galaxy collection install -r ../prereqs/requirements-collections.yml

# 5. Verify installation
echo ""
echo "=== Ansible Core Version ==="
ansible --version
echo ""
echo "=== Installed Collections ==="
ansible-galaxy collection list 
echo ""
echo "=== Python Packages ==="
pip3 list | grep -E 'ansible-core|jmespath|xmltodict|netaddr|paramiko'
echo ""
echo "✓ Control node setup complete!"
echo ""
echo "Next steps:"
echo "1. Build your RHEL 9.6/9.7 target machine"
echo "2. Prepare it with MariaDB, Python3, disabled SELinux"
echo "3. Determine how you'll provide BCM packages (network/local/dvd)"
echo "4. Run your BCM installation playbooks"
