# BCM 11.x Deployment — Direct Method

Deploy BCM 11.x directly on the target RHEL 9.x head node (no separate control node required).

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

--- 

## Prerequisites - Target Head Node
- RHEL 9.x system (not yet running BCM)
- Root access on the system itself
- Internet access to download packages, Ansible collections, and ISOs (for DVD method)
- Red Hat subscription manager registration completed.
- Git installed (or copy the repo manually)


## Step 1: Clone Repo and Set Up Head Node

On the target head node:

```bash
- Extract bundle in /root

cd bcm-ansible/playbooks/scripts
./run-01-controller-setup.sh
```

This installs:
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

## Step 2: Configure Cluster Settings

Edit `playbooks/group_vars/head_node/cluster-settings.yml`:

DO NOT USE DHCP AND STATIC AT SAME TIME.
| Setting | Description | Example |
|---|---|---|
| `external_interface` | NIC name for external (uplink) network | `enp6s18` |
| `external_ip_address` | DHCP or static IP | `DHCP` or `192.168.1.100` |
| `external_network_domain` | External Network Domain (Customer) | `hpc.customer.com` |
| `external_network_baseaddress` | Base address of external subnet | `192.168.1.0` |
| `external_network_netmask` | Netmask of external subnet | `255.255.255.0` |
| `external_network_gateway` | Gateway of external subnet | `192.168.1.1` |
|---|---|---|
| `management_interface` | NIC name for internal cluster network | `enp6s19` |
| `management_ip_address` | Head node IP on internal network | `172.16.0.1` |
| `management_network_baseaddress` | Base address of internal subnet | `172.16.0.0` |
| `management_network_netmask` | Netmask of internal subnet | `255.255.252.0` |
| `management_network_gateway` | Gateway for provisioning subnet (optional) | `172.16.0.1` |
|---|---|---|
| `timezone` | System timezone | `America/Denver` |
| `management_network_network_dns_range_start_offset` | DHCP Offset for Last IP in DHCP Range | `640` |
| `management_network_network_dns_range_end_offset` | DHCP Offset for Last IP in DHCP Range | `895` |


---

## Step 3: Choose Installation Method

Edit `playbooks/group_vars/head_node/cluster-install-method.yml`:

### Option A: DVD Installation

```yaml
install_medium: dvd
install_medium_dvd_path: /root/BCM11.0.iso
install_medium_dvd_checksum: ""  # Optional SHA256
```

Ensure the ISO file is already on the system at the specified path before running the installation playbook.

### Option B: Local Yum Repository

```yaml
install_medium: local
install_medium_local_repo_path:
  - /root/cm.repo
```

### Getting the cm.repo file.
The `cm.repo` file contains BCM yum repository credentials. Copy it to `/root/cm.repo` on the head node before proceeding.

This file is no longer located in this bundle, since it contains a password.  You will need to extract it from a valid BCM ISO

It is typically located inside here on the Rocky 9.6 DVD: 

  `<DVD>\data\packages\<version>\rocky\9u6\noarch\cm-config-yum-*.noarch.rpm (inside in /etc/yum.repos.d/)`

---

## Step 4: Configure Credentials (if needed)

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

## Step 5: Prepare Head Node

Configure the head node for BCM installation:

```bash
cd playbooks
ansible-playbook 30-prep-headnode.yml -i inventory/localhost
```

This playbook:
- Installs MariaDB and initializes the database
- Sets MariaDB root password (from credentials)
- Validates or copies `cm.repo` (for local installation method)
- Validates ISO path exists (for DVD installation method)
- Disables SELinux
- Sets up SSH access (for consistency with other deployments)

---

## Step 6: (RHEL 9.7 Only) Patch Installer Collection

If deploying to RHEL 9.7, patch the installed collection on this node:

The NVIDIA/Bright method is to use known paths, then upgrade after the installation is complete. This is has been tested 

```bash
cd playbooks
ansible-playbook 40-modify-installer-rhel97.yml -i inventory/localhost
```

This adds RHEL 9.7 support to the locally installed `brightcomputing.installer110` collection.

**Required:** Only tested with collection version `31.1.452+git66ec186`.

See [RHEL 9.7 Guide](docs/rhel97-guide.md) for details.

---

## Step 7: Install BCM

Choose one installation method:

### Method A: Install from DVD

Ensure the ISO is at the path specified in `cluster-install-method.yml` (`install_medium_dvd_path`).

```bash
cd playbooks/scripts
./run-54-install-bcm-dvd-local.sh --local
```

Or without the flag (defaults to `--local`):

```bash
cd playbooks/scripts
./run-54-install-bcm-dvd-local.sh
```

### Method B: Install from Local Yum Repository

Ensure `cm.repo` is at `/root/cm.repo` on the head node.

```bash
cd playbooks/scripts
./run-55-install-bcm-cmrepo-local.sh --local
```

Or without the flag (defaults to `--local`):

```bash
cd playbooks/scripts
./run-55-install-bcm-cmrepo-local.sh
```

---

## Post-Installation

### Validate System Health

After BCM installation completes:

```bash
playbooks/post-deploy/validate-system-health-postdeploy.sh
```

Checks: BCM services, disk usage, network connectivity, cmsh access, timeserver configuration.

### RHEL 9.7: Post-Install Steps

If deployed on RHEL 9.7, run these CMsh scripts in order:

```bash
cd playbooks/post-deploy
cmsh -f bcm-cmsh-scripts/rhel97-updatemodules.txt -q -x
cmsh -f bcm-cmsh-scripts/rhel97-modulecleanup.txt -q -x
cmsh -f bcm-cmsh-scripts/rhel97-startup.txt -q -x
```

See [RHEL 9.7 Guide](docs/rhel97-guide.md) for details.

---

## Troubleshooting

### "SELinux still enabled" after step 5

A reboot is required. The playbook warns about this:

```bash
reboot
```

Then proceed to step 6/7.

### "MariaDB root password already set"

Safe to re-run step 5. The playbook uses `ignore_errors` for password-set tasks.

### "ISO not found" during BCM installation

Verify the ISO exists at the path specified in `cluster-install-method.yml` (`install_medium_dvd_path`).

### "cm.repo not found" during BCM installation

Verify the file exists at `/root/cm.repo`. Copy it if missing:

```bash
cp files/cm.repo /root/cm.repo
```

### Collection version mismatch (RHEL 9.7)

Step 6 warns if the collection version differs from the tested version. Re-test before proceeding to production.

---

## References

- [Main README](README.md)
- [Controller-Based Method Guide](readme-controller-method.md)
- [RHEL 9.7 Guide](docs/rhel97-guide.md)

