---
title: "BCM 11.x Automated Deployment Guide"
subtitle: "Bright Cluster Manager on RHEL 9.x with Ansible"
author: "Dell Technologies — HPC Services"
date: "18 July 2026"
---

# Document Information

| Field | Value |
|---|---|
| Document | BCM 11.x Automated Deployment Guide |
| Applies to | Bright Cluster Manager 11.x on RHEL 9.6 / 9.7 |
| Automation | bcm-ansible repository, branch v2026.07-stable |
| Tested collection | brightcomputing.installer110 31.1.452+git66ec186 |
| Date | 18 July 2026 |

## Revision History

| Date | Change |
|---|---|
| 8 May 2026 | Completion of v1 activities |
| 18 July 2026 | Added RHEL release-lock requirement and enforcement, Ansible Vault password prompting, cm.repo handling |

---

# 1. Introduction

This guide describes the automated deployment of NVIDIA Bright Cluster Manager (BCM) 11.x onto RHEL 9.x head nodes using the **bcm-ansible** repository. The automation consists of six numbered Ansible playbooks executed in sequence, each with a corresponding wrapper script.

## 1.1 Supported Operating Systems

**As of 18 July 2026, this automation supports RHEL 9.6 and RHEL 9.7 only.**

- RHEL 9.6 is supported natively by the BCM installer collection.
- RHEL 9.7 requires an additional patch step (playbook 40) that modifies the installed `brightcomputing.installer110` collection in place. See Section 7.

The BCM installer performs a full system update during installation. An unlocked RHEL system will be pulled to the latest minor release (currently 9.8), which is unsupported. The RHEL minor release **must be locked** before deployment begins — see Section 3.3.

## 1.2 Deployment Pipeline Overview

| Order | Playbook | Purpose |
|---|---|---|
| 10 | 10-prep-captureserver.yml | Prepare a RHEL system for base-image capture |
| 20 | 20-grab-image.yml | Capture the compute-node base image archive |
| 30 | 30-prep-headnode.yml | Prepare the BCM head node (MariaDB, SELinux, repo/ISO validation) |
| 40 | 40-modify-installer-rhel97.yml | Patch the installer collection for RHEL 9.7 (RHEL 9.7 only) |
| 54 | 54-install-bcm-dvd.yaml | Install BCM from a DVD ISO |
| 55 | 55-install-bcm-cmrepo-local.yaml | Install BCM from a local yum repository |

Gaps in the numbering are reserved for future pipeline steps. Playbooks 54 and 55 are alternatives — run exactly one, according to the chosen installation method.

---

# 2. Deployment Methods

The automation supports two approaches. Both use the same playbooks; they differ only in where Ansible runs and which inventory is used.

## 2.1 Controller-Based Method (Recommended)

Ansible runs on a separate control node (Rocky Linux 9.x or RHEL 9.x) and deploys to remote head nodes over SSH. This allows managing multiple deployments from one location.

- Inventory: `playbooks/inventory/hosts`
- Wrapper script flag: `--hosts` (or `--remote`)

## 2.2 Direct Method

Ansible runs directly on the target head node itself. Suitable for single-node or offline deployments.

- Inventory: `playbooks/inventory/localhost`
- Wrapper script flag: `--local` (the default for most wrappers)

---

# 3. Prerequisites

## 3.1 Control Node (Controller-Based Method)

- Rocky Linux 9.x or RHEL 9.x
- Root or passwordless sudo
- Internet access for packages and Ansible collections
- Ansible Core 2.15.0 or later, Python 3.9 or later

## 3.2 Target Head Node

- RHEL 9.6 or 9.7, minimal (non-GUI) installation, not yet running BCM
- Registered with Red Hat Subscription Manager
- Root SSH access from the control node (controller method) or root access locally (direct method)
- Network access to package repositories

## 3.3 Lock the RHEL Minor Release (Required)

The BCM installer role runs a full `dnf` system update. Without a release lock, the OS is upgraded to the latest minor release (9.8 or later), which is not supported.

The lock must be applied at **two points**, in this order:

1. **Image-capture target — before playbook 10.** The lock is captured into the base image archive, which becomes the compute/default node image. Every compute node deployed from that image inherits the lock. An unlocked image produces compute nodes that update themselves onto an unsupported release.
2. **Head node — before playbooks 54/55.** Prevents the installer's system update from moving the head node past the supported release.

Apply and verify the lock:

```bash
subscription-manager release --set=9.7   # or 9.6, to match the deployment
dnf clean all
subscription-manager release --show
```

**Enforcement:** Playbooks 10 and 30 check the lock on RHEL targets and fail immediately if the release is not set to 9.6 or 9.7. The playbooks verify only — they never set the lock, because the release choice is a deliberate deployment decision.

## 3.4 Software Versions

| Component | Requirement |
|---|---|
| Ansible Core | >= 2.15.0 |
| Python | 3.9+ |
| ansible.netcommon | 5.3.0 |
| brightcomputing.installer110 | 31.1.452+git66ec186 (tested) |
| community.general, community.crypto, community.mysql, ansible.utils, ansible.posix | latest at install time |
| Python packages | jmespath 0.10.0, xmltodict 0.12.0, netaddr, paramiko |

Dependency sources of truth: `playbooks/prereqs/requirements-collections.yml` and `playbooks/prereqs/requirements-pip.txt`.

---

# 4. Security and Credentials

## 4.1 Sensitive Files

Two files contain credentials and must never be committed to version control in plaintext:

| File | Contents | Handling |
|---|---|---|
| `playbooks/group_vars/head_node/cluster-credentials.yml` | BCM product key, license identity, service passwords | Encrypt with Ansible Vault (Section 4.2) |
| `files/cm.repo` | Username and password for updates.brightcomputing.com | Not tracked in git; download from the Bright/NVIDIA customer portal and place at `files/cm.repo` (the `CM.REPO-goes-here` placeholder marks the location) |

## 4.2 Ansible Vault

Encrypt the credentials file before committing any change to it. Run from the `playbooks/` directory so `ansible.cfg` is picked up:

```bash
cd playbooks
ansible-vault encrypt group_vars/head_node/cluster-credentials.yml
ansible-vault edit group_vars/head_node/cluster-credentials.yml
```

## 4.3 Vault Password Handling

`playbooks/ansible.cfg` sets `vault_password_file` to `scripts/vault-pass-prompt.sh`. Every `ansible-playbook` and `ansible-vault` command obtains the vault password from one of two sources, in order:

1. The `ANSIBLE_VAULT_PASSWORD` environment variable, if set (intended for CI and other non-interactive runs).
2. An interactive terminal prompt (`Ansible Vault password:`). Input is hidden and never logged.

No vault password is stored on disk or in the repository. Distribute the password to team members out-of-band.

## 4.4 Credential Fields Reference

| Field | Description |
|---|---|
| `product_key` | BCM 11.x product license key (from Bright Computing / NVIDIA) |
| `license.*` | Organization identity: country, state, locality, organization, organizational unit, cluster name. The `mac` field is auto-populated from the head node's default interface — do not set manually. |
| `db_cmd_password`, `slurm_user_pass`, `ldap_root_pass`, `ldap_readonly_pass` | BCM service account passwords. Change all from defaults before production deployment. |
| `mysql_login_user`, `mysql_login_password` | MariaDB root credentials. Must match what playbook 30 configures; if changed afterward, re-run playbook 30. |

---

# 5. Configuration Reference

## 5.1 Inventory

| Inventory | Use |
|---|---|
| `playbooks/inventory/hosts` | Controller-based deployments. Defines `[head_node]` and `[image_target]` groups. |
| `playbooks/inventory/localhost` | Direct deployments, image capture, and local collection patching. Uses `ansible_connection: local`. |

Per-host overrides live in `playbooks/host_vars/<hostname>.yml`:

```yaml
ansible_host: 172.16.0.100
ansible_user: root
ansible_connection: ssh
```

## 5.2 Cluster Settings (cluster-settings.yml)

All variables apply to the `[head_node]` group. Do not configure DHCP and static external addressing at the same time.

| Variable | Description | Example |
|---|---|---|
| `post_install_default_image_archive` | Path on the head node to the compute-node base image tarball. Must exist before playbooks 54/55. Created by playbook 20. | `/root/RHEL9-compute-clone.tar.gz` |
| `cm_create_image_extra_args` | Extra arguments for BCM image creation. `-skip-gpu-drivers` excludes GPU drivers from the default image. | `""` |
| `external_network_name` | BCM name for the external (uplink) network | `externalnet` |
| `external_interface` | NIC name for the external network | `enp6s18` |
| `external_ip_address` | `DHCP` or a static IP | `DHCP` |
| `external_network_gateway` | Gateway (literal IP required when static) | `192.168.1.1` |
| `management_network_name` | BCM name for the internal management network | `internalnet` |
| `management_interface` | NIC name for the management network | `enp6s19` |
| `management_ip_address` | Head node IP on the management network | `172.16.0.1` |
| `management_network_baseaddress` | Management subnet base address | `172.16.0.0` |
| `management_network_netmask` | Management subnet netmask | `255.255.252.0` |
| `management_network_gateway` | Management network gateway | `172.16.0.1` |
| `management_network_network_dns_range_start_offset` | Integer offset from base address for the start of the compute DHCP range | `640` |
| `management_network_network_dns_range_end_offset` | Integer offset for the end of the DHCP range | `895` |
| `external_name_servers` | Upstream DNS resolvers | `[8.8.8.8, 8.8.4.4]` |
| `timezone` | Head node timezone | `America/Denver` |

## 5.3 Installation Method (cluster-install-method.yml)

| Setting | DVD method | Local repository method |
|---|---|---|
| `install_medium` | `dvd` | `local` |
| Required path | `install_medium_dvd_path` pointing to the BCM ISO on the head node | `install_medium_local_repo_path` pointing to `/root/cm.repo` |
| Install playbook | 54 | 55 |

Playbook 30 validates the chosen method's requirements and, for the local method, copies `files/cm.repo` to the head node automatically if absent.

---

# 6. Deployment Workflow

Run all wrapper scripts from `playbooks/scripts/`. All playbooks are run from the `playbooks/` directory (the wrappers handle this automatically).

## 6.0 OS Pre-Flight (Manual)

On each target system before automation begins:

1. Install RHEL (minimal, non-GUI), license with the customer's subscription (a developer key may be used if needed).
2. Configure disks per the customer design.
3. Set the hostname and the IP of the interface used for configuration.
4. Remove all other network connection profiles with `nmcli`/`nmtui` (housekeeping).
5. Register with Subscription Manager and **lock the minor release** (Section 3.3).
6. Copy or extract the bcm-ansible bundle to `/root`.

## 6.1 Step 0 — Generate SSH Key (controller method, one-time)

```bash
playbooks/scripts/00-ssh-keygen-controllernode.sh
```

Generates an ed25519 keypair at `~/.ssh/id_ed25519` (no passphrase). The public key is injected into target nodes by playbooks 10 and 30.

## 6.2 Step 1 — Set Up the Control Node (one-time)

```bash
cd playbooks/scripts
./run-01-controller-setup.sh
```

Installs EPEL, CRB, Python dependencies, and Ansible collections. Must be run from `playbooks/scripts/` so the relative paths to `../prereqs/` resolve. For the direct method, run this on the head node itself.

Verify:

```bash
ansible --version
ansible-galaxy collection list
pip3 list | grep -E 'jmespath|xmltodict|netaddr'
```

## 6.3 Step 2 — Prepare the Image-Capture Target

**Before this step:** lock the RHEL minor release on the capture target (Section 3.3). The lock is baked into the captured image. The playbook fails if the lock is not set.

```bash
cd playbooks/scripts
./run-10-prep-captureserver.sh --local     # or --hosts for a remote target
```

Verifies the release lock, injects the controller SSH key, installs EPEL and Python modules, and disables SELinux. If SELinux was enabled, **reboot before proceeding**.

## 6.4 Step 3 — Capture the Base Image

```bash
cd playbooks/scripts
./run-20-grab-host-image.sh --local -f RHEL9-compute-clone.tar.gz
```

Quiesces the filesystem and creates a compressed archive using the BCM `vm_archive` module. Place the resulting archive at the path configured in `post_install_default_image_archive` on the head node before Step 6.

## 6.5 Step 4 — Prepare the Head Node

```bash
cd playbooks/scripts
./run-30-prep-headnode.sh --hosts          # or --local for the direct method
```

Verifies the release lock, installs and initializes MariaDB, sets and validates the database root password, validates the chosen install medium (ISO present, or cm.repo present/copied), disables SELinux, and injects the controller SSH key. Reboot if SELinux was changed.

## 6.6 Step 5 — Patch the Installer for RHEL 9.7 (RHEL 9.7 only)

```bash
cd playbooks/scripts
./run-40-modify-installer-rhel97.sh
```

Runs on the control node only. Required before any RHEL 9.7 install; skip for RHEL 9.6. Must be re-run after any reinstall or upgrade of the `brightcomputing.installer110` collection. See Section 7.

## 6.7 Step 6 — Install BCM (choose one path)

Path A — DVD ISO:

```bash
cd playbooks/scripts
./run-54-install-bcm-dvd-local.sh --hosts
```

Requires `install_medium: dvd` and the ISO at `install_medium_dvd_path`. The playbook mounts the ISO at `/mnt/dvd` and verifies its contents before invoking the BCM head_node role.

Path B — Local yum repository:

```bash
cd playbooks/scripts
./run-55-install-bcm-cmrepo-local.sh --hosts
```

Requires `install_medium: local` and `cm.repo` at `/root/cm.repo` on the head node (copied automatically by playbook 30 if missing).

Both playbooks assert that the image archive and installation media exist before starting the long-running BCM installer role.

---

# 7. RHEL 9.7 Support

The tested version of the `brightcomputing.installer110` collection does not include RHEL 9.7. Playbook 40 patches the installed collection in place:

1. Adds `RedHat-9.7-x86_64` to the collection's `support_distros` list.
2. Copies `os_RedHat_9.6_vars.yml` to `os_RedHat_9.7_vars.yml` (RHEL 9.7 uses the same package layout as 9.6).
3. Creates selection symlinks `RHEL9u7-CM` and `RHEL9u7-DIST` pointing to their 9.6 counterparts.

The patch is idempotent. It is verified against collection version 31.1.452+git66ec186 only; the playbook warns if a different version is installed. To revert, force-reinstall the collection:

```bash
ansible-galaxy collection install brightcomputing.installer110 --force
```

## 7.1 Post-Install CMsh Steps (RHEL 9.7)

After BCM installation completes on RHEL 9.7, run these CMsh scripts in order from `playbooks/post-deploy/bcm-cmsh-scripts/`:

| Order | Script | Purpose |
|---|---|---|
| 1 | rhel97-updatemodules.txt | Adds `mpi3mr` (PERC 965 support) and `bonding` kernel modules to default-image |
| 2 | rhel97-modulecleanup.txt | Removes legacy SCSI/RAID/network drivers and ext3 (absent in RHEL 9.7) |
| 3 | rhel97-startup.txt | Rebuilds the default-image ramdisk after module changes |
| 4 (optional) | bcm-ansible-fix-node001.txt | Corrects node001 boot interface IP if duplicate/incorrect |

Execution:

```bash
cmsh < playbooks/post-deploy/bcm-cmsh-scripts/rhel97-updatemodules.txt
cmsh < playbooks/post-deploy/bcm-cmsh-scripts/rhel97-modulecleanup.txt
cmsh < playbooks/post-deploy/bcm-cmsh-scripts/rhel97-startup.txt
```

---

# 8. Post-Deployment

## 8.1 System Health Validation

Run on the head node:

```bash
playbooks/post-deploy/validate-system-health-postdeploy.sh
```

Checks BCM service states (tftpd, cmd, dhcpd, mariadb), disk usage thresholds, default-image boot files, network connections, cluster devices, and timeserver configuration. Output is color-coded: green healthy, yellow warning, red action required.

## 8.2 Image Cleanup Utilities

| Script | Purpose |
|---|---|
| `cleanup-deployed-image-with-cuda.sh <image-path>` | Removes firmware, desktop, audio, NVIDIA/CUDA packages, and old kernel trees from a BCM image directory |
| `remove-cuda-default-image.sh` | Removes NVIDIA/CUDA packages from `/cm/images/default-no-cuda/` only |
| `cleanup-rhel-subsciptions.sh [image-path]` | Unregisters RHEL subscriptions from the local system or an image installroot |

---

# 9. Troubleshooting

| Symptom | Resolution |
|---|---|
| Playbook 10 or 30 fails: "RHEL minor release is not locked" | Run `subscription-manager release --set=9.6` (or `9.7`) followed by `dnf clean all` on the target, then re-run. |
| System upgraded to RHEL 9.8 during install | The release was not locked before install. Lock the release, then roll back or rebuild the system. |
| Vault password errors / "vault password script returned non-zero" | No terminal was available to prompt. Set `ANSIBLE_VAULT_PASSWORD` for non-interactive runs. |
| "Collection ansible.posix does not support Ansible version X" | Upgrade: `pip install --upgrade "ansible-core>=2.15.0"`. |
| MariaDB root password already set | Safe to re-run playbook 30; the password task tolerates an existing password. |
| SELinux still enabled after prep | Reboot the target; the persistent change requires it. |
| Missing image archive at install time | Confirm the file at `post_install_default_image_archive` exists on the head node. |
| Product key locked during installation | Submit an unlock request via the Bright Computing customer portal; installation cannot proceed until unlocked. |
| BCM installer still rejects RHEL 9.7 after playbook 40 | Verify the patch applied (Section 7); re-run playbook 40. Re-apply after any collection upgrade. |
| Node001 has duplicate or incorrect IP after install | Run the `bcm-ansible-fix-node001.txt` CMsh script. |
| No timeservers configured | `cmsh -c "partition use base; set timeservers <ntphost>"` |

---

# 10. Appendix — Repository Layout

```
bcm-ansible/
  README.md                          Main documentation
  CLAUDE.md                          Project context for AI assistants
  docs/
    bcm-deployment-guide.md          This document
    rhel97-guide.md                  RHEL 9.7 patch details
  files/
    CM.REPO-goes-here                Placeholder for the downloaded cm.repo
    cm.repo                          BCM repo credentials (not tracked in git)
  playbooks/
    ansible.cfg                      Ansible configuration (vault prompt wired in)
    10..55 playbooks                 Deployment pipeline
    group_vars/head_node/            Cluster settings, install method, credentials
    host_vars/                       Per-host overrides
    inventory/                       hosts (remote) and localhost inventories
    post-deploy/                     Validation, cleanup, and CMsh scripts
    prereqs/                         Collection and pip requirements
    scripts/                         Wrapper scripts and vault-pass-prompt.sh
```
