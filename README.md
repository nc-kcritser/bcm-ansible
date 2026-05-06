# BCM 11.x Ansible Automation for RHEL 9.x

Automated deployment of Bright Cluster Manager (BCM) 11.x on RHEL 9.x head nodes using Ansible. This repo provides six numbered playbooks that execute in sequence, supporting both DVD-based and local yum repository installation methods. **Note:** RHEL 9.7 deployments require an additional patch step (see [RHEL 9.7 Guide](docs/rhel97-guide.md)).

---

## Repository Layout

```
bcm-ansible/
├── README.md                                          # This file
├── files/
│   └── cm.repo                                        # This file needs to be placed here for local repo installs
├── docs/
│   └── rhel97-guide.md                               # RHEL 9.7-specific setup and patching
└── playbooks/
    ├── ansible.cfg                                    # Ansible configuration
    ├── 10-prep-captureserver.yml                     # Prepare target for image capture
    ├── 20-grab-image.yml                             # Capture base compute image
    ├── 30-prep-headnode.yml                          # Prepare BCM head node
    ├── 40-modify-installer-rhel97.yml                # Patch installer for RHEL 9.7 (if needed)
    ├── 54-install-bcm-dvd.yaml                       # Install BCM from ISO
    ├── 55-install-bcm-cmrepo-local.yaml              # Install BCM from local yum repo
    ├── group_vars/head_node/
    │   ├── cluster-credentials.yml                   # BCM license, passwords (SENSITIVE)
    │   ├── cluster-install-method.yml                # Install method toggle (dvd/local)
    │   └── cluster-settings.yml                      # Network, timezone, image paths
    ├── host_vars/
    │   ├── localhost.yml
    │   └── rhel96-base.yml                           # Per-host overrides
    ├── inventory/
    │   ├── hosts                                      # Remote hosts inventory
    │   └── localhost                                  # Local execution inventory
    ├── post-deploy/                                   # Post-installation utilities
    │   ├── bcm-cmsh-scripts/                          # CMsh command transcripts
    │   │   ├── bcm-ansible-fix-node001.txt
    │   │   ├── rhel97-modulecleanup.txt
    │   │   ├── rhel97-startup.txt
    │   │   └── rhel97-updatemodules.txt
    │   ├── cleanup-deployed-image-with-cuda.sh       # Strip bloat from BCM images
    │   ├── cleanup-rhel-subsciptions.sh              # Unregister RHEL subscriptions
    │   ├── remove-cuda-default-image.sh              # Remove CUDA from an image.
    │   └── validate-system-health-postdeploy.sh      # Health check after install
    ├── prereqs/                                       # Dependencies
    │   ├── requirements-collections.yml              # Ansible collections
    │   └── requirements-pip.txt                      # Python packages
    └── scripts/                                       # Wrapper scripts
        ├── 00-ssh-keygen-controllernode.sh
        ├── 01-controller-setup.sh
        ├── run-10-prep-captureserver.sh
        ├── run-20-grab-host-image.sh
        ├── run-30-prep-headnode.sh
        ├── run-40-modify-installer-rhel97.sh
        ├── run-54-install-bcm-dvd-local.sh
        └── run-55-install-bcm-cmrepo-local.sh
```

---

## Prerequisites

### Control Node
- **OS:** Rocky Linux 9.x or RHEL 9.x
- **Access:** Root or passwordless sudo
- **Network:** Internet access to download packages and collections

### Versions
- **Ansible Core:** >= 2.15.0
- **Python:** 3.9+
- **Collections:** See `playbooks/prereqs/requirements-collections.yml`
  - `ansible.netcommon==5.3.0`
  - `brightcomputing.installer110`
  - `community.general`
  - `community.crypto`
  - `community.mysql`
  - `ansible.utils`
  - `ansible.posix`
- **Python Packages:** See `playbooks/prereqs/requirements-pip.txt`
  - `ansible-core>=2.15.0`
  - `jmespath==0.10.0`
  - `xmltodict==0.12.0`
  - `netaddr`
  - `paramiko`

---

## Deployment Methods

This repo supports two deployment approaches:

### Method 1: Controller-Based Deployment (Recommended)
Run Ansible from a separate control node against the target head node(s). Allows managing multiple deployments from one location.

**Prerequisites:**
- Separate control node (Rocky/RHEL 9.x)
- Network connectivity from control node to all target head nodes
- SSH access (pubkey auth) to target nodes

**Setup:** Steps 0–1 run once on the control node. Steps 2–6 run against target head nodes.

### Method 2: Direct Deployment
Run Ansible directly on the target head node (uses `localhost` inventory). Useful for single-node setups or offline deployments.

**Prerequisites:**
- RHEL 9.x head node with network access (to download packages/collections)
- Root access on the head node itself

**Setup:** Step 1 runs on the head node. Steps 2–6 run locally using `inventory/localhost`.

---

## Initial Setup

The setup steps differ slightly depending on your deployment method.

### Controller-Based Method

#### Step 0: Generate SSH Key (one-time on control node)

```bash
playbooks/scripts/00-ssh-keygen-controllernode.sh
```

Generates `~/.ssh/id_ed25519` (ed25519 key, no passphrase). Required so the controller can SSH into target head nodes.

#### Step 1: Set Up Control Node (one-time)

```bash
cd playbooks/scripts
./01-controller-setup.sh
```

Installs EPEL, Ansible collections, and Python packages from `../prereqs/`. The script must be run from `playbooks/scripts/` so relative paths resolve correctly.

After setup, verify installation:

```bash
ansible --version
ansible-galaxy collection list
pip3 list | grep -E 'jmespath|xmltodict|netaddr'
```

---

### Direct Method

#### Step 1: Set Up Head Node (one-time on target RHEL 9.x system)

```bash
cd /path/to/bcm-ansible/playbooks/scripts
./01-controller-setup.sh
```

Installs EPEL, Ansible collections, and Python packages. The script must be run from `playbooks/scripts/` directory so relative paths resolve correctly.

After setup, verify installation:

```bash
ansible --version
ansible-galaxy collection list
pip3 list | grep -E 'jmespath|xmltodict|netaddr'
```

Then proceed to Step 2 (Prepare Image Capture Target) in the workflow below, using `inventory/localhost` instead of `inventory/hosts`.

---

## Setting Up a New Head Node

To deploy to a new head node (e.g., `tornado`), follow this checklist:

### Controller-Based Deployment

1. **Create host variables** for the new head node:
   ```bash
   cp playbooks/host_vars/rhel96-base.yml playbooks/host_vars/tornado.yml
   ```

2. **Update the IP address** in `playbooks/host_vars/tornado.yml`:
   ```yaml
   ansible_host: 172.16.0.100  # Replace with tornado's IP
   ansible_user: root
   ansible_connection: ssh
   ```

3. **Add tornado to inventory** in `playbooks/inventory/hosts`:
   ```ini
   [head_node]
   tornado ansible_host=172.16.0.100

   [image_target]
   # (leave empty if not capturing images)
   ```

4. **Adjust cluster settings** in `playbooks/group_vars/head_node/`:
   - `cluster-settings.yml` — Network interfaces, IPs, gateway, timezone for tornado
   - `cluster-install-method.yml` — Choose `dvd` or `local` install method
   - `cluster-credentials.yml` — BCM license key and passwords (optional if same as before)

5. **Run the workflow** (Steps 2–6 of the end-to-end section below), targeting tornado.

### Direct Deployment

1. **On tornado** (the target head node), clone this repo or copy the `playbooks/` directory.

2. **Run Step 1** (control node setup) on tornado.

3. **Adjust cluster settings** in `playbooks/group_vars/head_node/`:
   - `cluster-settings.yml` — Network configuration for tornado
   - `cluster-install-method.yml` — Install method
   - `cluster-credentials.yml` — License and passwords

4. **Run the workflow** (Steps 2–6 below) using `inventory/localhost`.

---

## Configuration Reference

Before running any deployment playbooks, configure your environment.

### Inventory

Two inventories are provided:

- **`playbooks/inventory/hosts`** — Remote head node and compute targets. Define `[head_node]` and `[image_target]` groups here. Per-host settings go in `playbooks/host_vars/`.
- **`playbooks/inventory/localhost`** — For image capture and local patching. Uses `ansible_connection: local`.

Each host can have overrides in `host_vars/<hostname>.yml`:
- `ansible_host`: IP or hostname
- `ansible_user`: SSH user (usually `root`)
- `ansible_connection`: `ssh` or `local`

### cluster-settings.yml

Core deployment variables. All variables apply to the `[head_node]` group:

| Variable | Description | Default/Example |
|---|---|---|
| `post_install_default_image_archive` | Path on head node to the compute node base image tarball used during BCM install. **Must exist before running playbook 54 or 55.** Created by playbook 20. DVD install wrapper overrides to `/root/RHEL9u6.tar.gz`. | `/root/RHEL9-compute-clone.tar.gz` |
| `cm_create_image_extra_args` | Extra args passed to BCM's image creation step. Set to `-skip-gpu-drivers` to exclude GPU drivers from the default image. Empty string means GPU drivers are included. | `""` |
| `external_network_name` | BCM name for the external (uplink) network | `externalnet` |
| `external_interface` | NIC name for external network on head node (e.g., `enp6s18`, `eth0`) | `enp6s18` |
| `external_ip_address` | `DHCP` for dynamic assignment, or specify a static IP | `DHCP` |
| `management_network_name` | BCM name for the internal cluster management network | `internalnet` |
| `management_interface` | NIC name for the management/internal network (e.g., `enp6s19`, `eth1`) | `enp6s19` |
| `management_ip_address` | Head node IP on the management network | `172.16.0.1` |
| `management_network_baseaddress` | Base address of the management subnet | `172.16.0.0` |
| `management_network_netmask` | Netmask for the management subnet (e.g., class C or smaller for compute range) | `255.255.252.0` |
| `management_network_gateway` | Default gateway on management network | `172.16.0.1` |
| `management_network_network_dns_range_start_offset` | Integer offset from base address for start of compute node DHCP range. Example: `172.16.0.0/22` with offset `768` = `172.16.3.0` | `768` |
| `management_network_network_dns_range_end_offset` | Integer offset for end of DHCP range. Example: with offset `1022` = `172.16.3.254` | `1022` |
| `external_name_servers` | List of upstream DNS resolvers | `[8.8.8.8, 8.8.4.4]` |
| `timezone` | System timezone for head node | `America/Denver` |

**DHCP vs. Static External Network:** By default, the external interface uses DHCP and auto-detects the gateway. To switch to static IP, uncomment the static block in `cluster-settings.yml` and comment out the DHCP block. When static, `external_network_gateway` must be a literal IP address (not a fact lookup).

### cluster-install-method.yml

Controls which BCM installation method to use and the required paths:

- **`install_medium: dvd`** — Install from an ISO file. Requires `install_medium_dvd_path` pointing to a `.iso` file on the head node. Playbook 54 runs.
- **`install_medium: local`** — Install from a local yum repository. Requires `install_medium_local_repo_path` pointing to `/root/cm.repo` (or another path). Playbook 55 runs. Playbook 30 will automatically copy `files/cm.repo` from the controller if the file is absent on the head node.

Note: Playbook 30 (`prep-headnode`) also branches on this variable to validate the chosen method's requirements.

### cluster-credentials.yml

Contains BCM license key, organization identity, and service account passwords.

| Field | Description |
|---|---|
| `product_key` | BCM 11.x product license key. Provided by Bright Computing / NVIDIA. |
| `license.*` | Organization fields: country, state, locality, organization, organizational_unit, cluster_name. The `mac` field is auto-populated from `ansible_default_ipv4.macaddress` — do not set manually. |
| `db_cmd_password`, `slurm_user_pass`, `ldap_root_pass`, `ldap_readonly_pass` | BCM service account passwords. Change all from defaults before production deployment. |
| `mysql_login_user`, `mysql_login_password` | MariaDB root credentials. Must match what playbook 30 sets. If changed here after prep, re-run playbook 30. |

**⚠️ SECURITY:** This file contains real passwords and license keys. Never commit it unencrypted to a public repository. Use `ansible-vault`:

```bash
ansible-vault encrypt playbooks/group_vars/head_node/cluster-credentials.yml
ansible-vault edit playbooks/group_vars/head_node/cluster-credentials.yml
```

Optionally uncomment `vault_password_file` in `playbooks/ansible.cfg` to automate decryption during playbook runs.

---

## End-to-End Workflow

Follow these steps in order to deploy BCM on a RHEL 9.x head node.

### Step 0: Generate SSH Key
**Script:** `playbooks/scripts/00-ssh-keygen-controllernode.sh`  
**When:** One-time on a fresh control node.  
**What:** Generates ed25519 SSH keypair at `~/.ssh/id_ed25519`.

### Step 1: Set Up Control Node
**Script:** `cd playbooks/scripts && ./01-controller-setup.sh`  
**When:** One-time.  
**What:** Installs Ansible, Python packages, and Ansible collections from `prereqs/`.

### Step 2: Prepare Image Capture Target
**Script:** `playbooks/scripts/run-10-prep-captureserver.sh [--local|--hosts]`  
**Playbook:** `playbooks/10-prep-captureserver.yml`  
**When:** To build a fresh compute node base image.  
**What:** Injects SSH public key, installs EPEL + Python pip modules, disables SELinux.  
**Note:** If SELinux is disabled, a reboot is required.

### Step 3: Capture Base Image
**Script:** `playbooks/scripts/run-20-grab-host-image.sh [--local|--hosts] [-f filename]`  
**Playbook:** `playbooks/20-grab-image.yml`  
**When:** After Step 2, to snapshot the prepared system.  
**What:** Quiesces filesystems and creates a compressed archive using `brightcomputing.installer110.vm_archive`.  
**Output:** Default is `RHEL9-compute-clone.tar.gz` (override with `-f`).  
**Note:** The resulting `.tar.gz` must be placed at the path specified in `post_install_default_image_archive` before running Steps 4–6.

### Step 4: Prepare Head Node
**Script:** `playbooks/scripts/run-30-prep-headnode.sh [--local|--hosts]`  
**Playbook:** `playbooks/30-prep-headnode.yml`  
**When:** Before BCM installation.  
**What:**  
- Installs MariaDB, initializes database, sets root password.
- Validates or copies `cm.repo` (local install method).
- Validates ISO path exists (DVD install method).
- Disables SELinux.
- Adds Ansible controller's SSH public key to root authorized_keys.

### Step 5: (RHEL 9.7 Only) Patch Installer Collection
**Script:** `playbooks/scripts/run-40-modify-installer-rhel97.sh`  
**Playbook:** `playbooks/40-modify-installer-rhel97.yml`  
**When:** Required for RHEL 9.7 deployments. Can be skipped for RHEL 9.6 and earlier.  
**What:** Patches the locally installed `brightcomputing.installer110` collection to add RHEL 9.7 support.  
**Warning:** Only tested with collection version `31.1.452+git66ec186`. See [RHEL 9.7 Guide](docs/rhel97-guide.md) for details.  
**Note:** Must be re-applied after any collection upgrade.

### Step 6: Install BCM (choose one path)

#### Path A: Install from DVD
**Script:** `playbooks/scripts/run-54-install-bcm-dvd-local.sh`  
**Playbook:** `playbooks/54-install-bcm-dvd.yaml`  
**Requirements:**  
- `install_medium: dvd` in `cluster-install-method.yml`
- ISO file at path specified by `install_medium_dvd_path`

#### Path B: Install from Local Yum Repository
**Script:** `playbooks/scripts/run-55-install-bcm-cmrepo-local.sh`  
**Playbook:** `playbooks/55-install-bcm-cmrepo-local.yaml`  
**Requirements:**  
- `install_medium: local` in `cluster-install-method.yml`
- `cm.repo` file at `/root/cm.repo` on head node (playbook 30 copies it automatically if missing)

---

## Post-Deployment

### System Health Validation

Run on the head node after BCM installation:

```bash
playbooks/post-deploy/validate-system-health-postdeploy.sh
```

Checks:
- BCM service states (`tftpd`, `cmd`, `dhcpd`, `mariadb`) — green (healthy), yellow (warnings), red (action required)
- Disk usage with color thresholds (80%+ red, 60–80% yellow)
- Default image boot files (`/cm/images/default-image/boot/`, `vmlinuz`)
- Network connections via `nmcli`
- Cluster devices via `cmsh`
- Timeserver configuration via `cmsh`

### CMsh Scripts

Interactive CMsh command transcripts in `playbooks/post-deploy/bcm-cmsh-scripts/`. Run via:

```bash
cmsh < scriptname.txt
```

Or copy/paste commands interactively.

| Script | Purpose |
|---|---|
| `bcm-ansible-fix-node001.txt` | Corrects node001's boot interface IP to `172.16.0.101`. Run if node has duplicate or incorrect IP. |
| `rhel97-updatemodules.txt` | Adds `mpi3mr` and `bonding` kernel modules to `default-image`. Needed for RHEL 9.7. |
| `rhel97-modulecleanup.txt` | Removes legacy/conflicting kernel modules from `default-image` (virtio, old SCSI drivers). Needed for RHEL 9.7. |
| `rhel97-startup.txt` | Rebuilds ramdisk for `default-image`. Run after any module changes. |

### Image Cleanup Scripts

- **`cleanup-deployed-image-with-cuda.sh <image-path>`** — Removes firmware, desktop packages, audio, all NVIDIA/CUDA packages, and old kernel module trees from a BCM image directory. Example: `./cleanup-deployed-image-with-cuda.sh /cm/images/default-nocuda`.

- **`remove-cuda-default-image.sh`** — Hardcoded version that removes NVIDIA/CUDA packages only from `/cm/images/default-no-cuda/`. Simpler than the above if that's all you need.

- **`cleanup-rhel-subsciptions.sh [image-path]`** — Unregisters RHEL subscriptions from either the local system (no argument) or an image installroot. Example: `./cleanup-rhel-subsciptions.sh /cm/images/default-image`.

---

## RHEL 9.7 Support

The `brightcomputing.installer110` collection does not ship with RHEL 9.7 support in the version tested here. Playbook 40 patches the installed collection in-place to add support.

**See [RHEL 9.7 Guide](docs/rhel97-guide.md) for detailed setup and post-install steps.**

---

## Troubleshooting

### "Collection ansible.posix does not support Ansible version X"
Upgrade ansible-core:
```bash
pip install --upgrade "ansible-core>=2.15.0"
```

### MariaDB root password already set
Safe to re-run playbook 30. It uses `ignore_errors` for the password-set task.

### SELinux still enabled after prep
A reboot is required. Playbook 30 warns about this.

### Missing image archive at install time
Verify the path specified in `post_install_default_image_archive` exists on the head node and is readable.

### CMsh device IP conflict after install
Run the CMsh script `playbooks/post-deploy/bcm-cmsh-scripts/bcm-ansible-fix-node001.txt` to correct the IP.

### No timeservers configured after install
Run the fix command shown in the output of `validate-system-health-postdeploy.sh`:
```bash
cmsh -c "partition use base; set timeservers <ntphost>"
```

---

## Security Notes

- **`files/cm.repo`** contains BCM yum repository credentials (username and password in plaintext). Do not commit to public repositories.
- **`cluster-credentials.yml`** contains BCM product key, license info, and passwords. Encrypt with `ansible-vault` before committing.
- **Vault support** is available via the uncommented `vault_password_file` option in `playbooks/ansible.cfg`.

---

## References

- [Bright Computing BCM Documentation](https://www.brightcomputing.com)
- [Ansible Documentation](https://docs.ansible.com/)
- [RHEL 9.7 Support](docs/rhel97-guide.md)
