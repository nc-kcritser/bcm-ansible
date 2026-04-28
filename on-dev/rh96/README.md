## Control Node Setup

Before running any playbooks, you must set up your control node (the machine from which you'll run Ansible).

### Prerequisites

- Rocky Linux 9.x or RHEL 9.x
- Internet access to download packages and collections
- Root or sudo access

### Setup

Run the provided setup script on your control node:

```bash
./control-node-setup.sh
```

This script will:
1. Install EPEL repository and enable CRB (Code Ready Builder)
2. Install `ansible-core` and Python 3
3. Upgrade `ansible-core` to version 2.15.0 or higher (required for `ansible.posix` collection)
4. Install required Python packages: jmespath, xmltodict, netaddr
5. Install Ansible collections:
   - `brightcomputing.installer110` (BCM installer)
   - `community.general`
   - `community.crypto`
   - `community.mysql`
   - `ansible.posix`
6. Verify all installations

### Version Requirements

- **Ansible Core**: >= 2.15.0 (automatically upgraded by the script)
- **ansible.posix collection**: Requires ansible-core >= 2.15.0
- **Python**: 3.9+

### Manual Verification

After running the setup script, verify your installation:

```bash
# Check Ansible version
ansible --version

# List installed collections
ansible-galaxy collection list

# Check Python packages
pip3 list | grep -E 'jmespath|xmltodict|netaddr'
```

### Troubleshooting

**"Collection ansible.posix does not support Ansible version X"**

This means ansible-core is older than 2.15.0. Upgrade it:

```bash
pip install --upgrade "ansible-core>=2.15.0"
```

**Missing Python packages**

Manually install missing packages:

```bash
pip3 install jmespath xmltodict netaddr
```

**Collection installation fails**

Ensure you have internet access and try again:

```bash
ansible-galaxy collection install brightcomputing.installer110 --force
```