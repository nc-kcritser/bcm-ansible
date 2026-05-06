# BCM 11.x Deployment — Controller-Based Method

Deploy BCM 11.x to remote RHEL 9.x head nodes from a separate control node running Ansible.

---

## Prerequisites

### Control Node
- Rocky Linux 9.x or RHEL 9.x
- Root or passwordless sudo access
- Internet access to download packages and Ansible collections

### Target Head Node(s)
- RHEL 9.x system (not yet running BCM)
- SSH access from control node (pubkey auth, root user)
- Network connectivity to reach package repositories and (for DVD method) ISO location

### Versions
- Ansible Core >= 2.15.0
- Python 3.9+
- See `playbooks/prereqs/requirements-collections.yml` for required collections

---

## Pre-flight Run - Install the Operating System

- Install RedHat OS
- License the installation (prefer using the customer's key, you can use a developer key if needed.)
- Setup the Disk Manually based on customer designs.
- Set up the server for minimal non GUI.
- Set the hostname
- Set the IP for the interface you are going to use 

### After the Install Completes

- Download the bundle to /root and expand. 
- Using nmcli/nmtui ... remove all interfaces other that the interface you are using for configuration (this is a housekeeping step).


## Step 0: Generate SSH Key (one-time on control node)

```bash
playbooks/scripts/00-ssh-keygen-controllernode.sh
```

Generates `~/.ssh/id_ed25519` (ed25519 key, no passphrase).

This key is injected into target head nodes by the playbooks so the controller can connect via SSH.

---

## Step 1: Set Up Control Node (one-time)

```bash
cd playbooks/scripts
./01-controller-setup.sh
```

Installs:
- EPEL repository and CRB
- Ansible Core >= 2.15.0
- Python packages (jmespath, xmltodict, netaddr, paramiko)
- Ansible collections (ansible.posix, community.general, community.crypto, community.mysql, ansible.utils, ansible.netcommon, brightcomputing.installer110)

**The script must be run from `playbooks/scripts/`** so relative paths resolve correctly.

### Verify Installation

```bash
ansible --version
ansible-galaxy collection list
pip3 list | grep -E 'jmespath|xmltodict|netaddr'
```

---

## Step 2: Set Up a New Target Head Node

For each new head node (e.g., `tornado`):

### 2a. Create Host Variables

```bash
cp playbooks/host_vars/rhel96-base.yml playbooks/host_vars/tornado.yml
```

Edit `playbooks/host_vars/tornado.yml`:

```yaml
ansible_host: 172.16.0.100       # Target head node IP
ansible_user: root
ansible_connection: ssh
```

### 2b. Add to Inventory

Edit `playbooks/inventory/hosts`, add to `[head_node]` group:

```ini
[head_node]
tornado

[image_target]
tornado
# Put a different identiy here if pulling from a different capture node.
```

### 2c. Configure Cluster Settings

Edit `playbooks/group_vars/head_node/cluster-settings.yml`:

| Setting | Description | Example |
|---|---|---|
| `external_interface` | NIC name for external (uplink) network | `enp6s18` |
| `external_ip_address` | DHCP or static IP | `DHCP` or `192.168.1.100` |
| `management_interface` | NIC name for internal cluster network | `enp6s19` |
| `management_ip_address` | Head node IP on internal network | `172.16.0.1` |
| `management_network_baseaddress` | Base address of internal subnet | `172.16.0.0` |
| `management_network_netmask` | Netmask of internal subnet | `255.255.252.0` |
| `timezone` | System timezone | `America/Denver` |

### 2d. Choose Installation Method

Edit `playbooks/group_vars/head_node/cluster-install-method.yml`:

**Option A: DVD Installation**
```yaml
install_medium: dvd
install_medium_dvd_path: /root/BCM11.0.iso    # Path on head node
install_medium_dvd_checksum: ""               # Optional SHA256
```

**Option B: Local Yum Repository**
```yaml
install_medium: local
install_medium_local_repo_path:
  - /root/cm.repo
```

The `cm.repo` file will be auto-copied from the controller if missing on the head node.

### 2e. Configure Credentials

Edit `playbooks/group_vars/head_node/cluster-credentials.yml`:

```yaml
product_key: YOUR_BCM_LICENSE_KEY

license:
  country: US
  state: Colorado
  locality: Denver
  organization: Your Organization
  organizational_unit: Your Unit
  cluster_name: your-cluster

db_cmd_password: <password>
slurm_user_pass: <password>
ldap_root_pass: <password>
ldap_readonly_pass: <password>

mysql_login_user: root
mysql_login_password: <password>
```

---

## Step 3: Prepare Image Capture Target

Prepare a separate RHEL 9.x system (physical or VM) for capture:

```bash
cd playbooks/scripts
./run-10-prep-captureserver.sh --hosts
```

This:
- Adds the controller's SSH public key
- Installs EPEL and Python packages
- Disables SELinux

**If SELinux was disabled, reboot the target after this step.**

---

## Step 4: Capture Base Image

Snapshot the prepared system into a tarball:

```bash
cd playbooks/scripts
./run-20-grab-host-image.sh --hosts 
```

Output: `/root/RHEL9-compute-clone.tar.gz` on the capture target.

**Copy this file to the target head node at the path specified in `cluster-settings.yml` (`post_install_default_image_archive`) before proceeding.**

---

## Step 5: Prepare Head Node

Configure the target head node for BCM installation:

```bash
cd playbooks/scripts
./run-30-prep-headnode.sh --hosts
```

This playbook:
- Installs MariaDB and initializes the database
- Sets MariaDB root password (from credentials)
- Validates or copies `cm.repo` (for local installation method)
- Validates ISO path exists (for DVD installation method)
- Disables SELinux
- Adds the controller's SSH public key to root's `authorized_keys`

---

## Step 6: (RHEL 9.7 Only) Patch Installer Collection

If deploying to RHEL 9.7, patch the collection on the controller:

```bash
cd playbooks/scripts
./run-40-modify-installer-rhel97.sh
```

This adds RHEL 9.7 support to the locally installed `brightcomputing.installer110` collection.

**Required:** Only tested with collection version `31.1.452+git66ec186`.

See [RHEL 9.7 Guide](docs/rhel97-guide.md) for details.

---

## Step 7: Install BCM

Choose one installation method:

### Method A: Install from DVD

Ensure the ISO file is on the head node at the path specified in `cluster-install-method.yml` (`install_medium_dvd_path`).

```bash
cd playbooks/scripts
./run-54-install-bcm-dvd-local.sh --hosts
```

### Method B: Install from Local Yum Repository

Ensure `cm.repo` is at `/root/cm.repo` on the head node (playbook 5 copies it automatically).

```bash
cd playbooks/scripts
./run-55-install-bcm-cmrepo-local.sh --hosts
```

---

## Post-Installation

### Validate System Health

Run on the head node after BCM installation completes:

```bash
playbooks/post-deploy/validate-system-health-postdeploy.sh
```

Checks: BCM services, disk usage, network connectivity, cmsh access, timeserver configuration.

### RHEL 9.7: Post-Install Steps (Optional)

If deployed on RHEL 9.7, run these CMsh scripts in order:

```bash
cmsh -f playbooks/post-deploy/bcm-cmsh-scripts/rhel97-updatemodules.txt
cmsh -f playbooks/post-deploy/bcm-cmsh-scripts/rhel97-modulecleanup.txt
cmsh -f playbooks/post-deploy/bcm-cmsh-scripts/rhel97-startup.txt
```

See [RHEL 9.7 Guide](docs/rhel97-guide.md) for details.

---

## Troubleshooting

### "SSH: permission denied" when running playbooks

Verify SSH key was generated and copied to target head node:

```bash
ssh -i ~/.ssh/id_ed25519 root@<head-node-ip> "echo OK"
```

If it fails:
- Ensure step 0 was completed
- Manually copy the key: `ssh-copy-id -i ~/.ssh/id_ed25519 root@<head-node-ip>`
- Check that target allows root SSH login and pubkey auth

### SELinux still enabled after step 5

A reboot is required. The playbook warns about this.

### "ISO not found" during BCM installation

Verify the ISO file exists on the head node at the path specified in `cluster-install-method.yml`.

### Collection version mismatch (RHEL 9.7)

Step 6 warns if the collection version differs from the tested version. Re-test before proceeding to production.

---

## References

- [Main README](README.md)
- [Direct Method Guide](readme-direct-method.md)
- [RHEL 9.7 Guide](docs/rhel97-guide.md)
- [CLAUDE.md](CLAUDE.md) — Project context
