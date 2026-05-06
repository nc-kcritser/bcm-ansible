# bcm-ansible — Project Context for Claude

## Project Purpose

This repository automates deployment of Bright Cluster Manager (BCM) 11.x on RHEL 9.x systems using Ansible. The deployment is organized as a sequence of numbered playbooks (`10-*`, `20-*`, `30-*`, etc.) that run in order. Each playbook has a corresponding wrapper script in `playbooks/scripts/run-NN-*.sh`.

**All playbooks live in `playbooks/`.** Scripts must be run from the `playbooks/scripts/` directory so their relative paths to `../prereqs/` and other assets resolve correctly.

---

## Key Architectural Decisions

### Playbook Numbering
The playbook numbers (10, 20, 30, 40, 54, 55) denote the intended execution order. Gaps (no 11–19, 21–29, 31–39, 41–53) are reserved for future steps in the BCM deployment pipeline.

### Two Separate Install Playbooks
Playbooks 54 (DVD) and 55 (local yum) are entirely separate rather than one conditional playbook. This design minimizes the blast radius of failures during the long-running BCM installer role (both methods use the same upstream `brightcomputing.installer110` role, but paths to the artifacts differ greatly).

### Playbook 40 — Idempotent Collection Patch
Playbook 40 is a **destructive in-place patch** to the installed `brightcomputing.installer110` collection on the control node. It modifies files inside the collection directory to add RHEL 9.7 support. The patch is idempotent (already-patched files are not changed), but **must be re-applied after any collection reinstall or upgrade** because those operations overwrite the collection files.

### Ansible Configuration
`playbooks/ansible.cfg` sets the default inventory to `inventory/hosts` (remote deployments). Playbooks that target localhost (e.g., playbook 20 for image capture, playbook 40 for patching) explicitly pass `-i inventory/localhost` to use the local inventory.

---

## Sensitive Files — Do Not Expose Actual Values

These files contain credentials, license keys, or other sensitive data:

- **`playbooks/group_vars/head_node/cluster-credentials.yml`** — BCM product key, license info, database and system passwords. All values should be changed from defaults before any production deployment.
- **`files/cm.repo`** — Contains username and password for `updates.brightcomputing.com` (BCM yum repository credentials, plaintext).

In documentation, comments, or examples, refer to these files by name and note that they contain sensitive data, but never expose actual values in code, logs, or version control.

---

## Running Playbooks

### From the `playbooks/` Directory

Always run playbooks from the `playbooks/` directory (where `ansible.cfg` lives), or use the wrapper scripts in `playbooks/scripts/`, which handle the `cd` automatically.

```bash
# Correct
cd playbooks
ansible-playbook 30-prep-headnode.yml -i inventory/hosts

# Or use the wrapper
cd playbooks/scripts
./run-30-prep-headnode.sh --hosts
```

### Collections and Python Dependencies

**Source of truth:**
- Collections: `playbooks/prereqs/requirements-collections.yml`
- Python packages: `playbooks/prereqs/requirements-pip.txt`

The `playbooks/scripts/01-controller-setup.sh` script installs both. It must be run from `playbooks/scripts/` so the relative paths (`../prereqs/`) resolve correctly.

---

## RHEL 9.7 Support

The `brightcomputing.installer110` collection does not ship with RHEL 9.7 support out-of-the-box (as of the version tested: `31.1.452+git66ec186`).

**Playbook 40 patches the installed collection in-place to add RHEL 9.7 support.**

See `docs/rhel97-guide.md` for full details on:
- What the patch does (adds RHEL 9.7 to supported distros, copies vars, creates symlinks)
- When to run it (before RHEL 9.7 BCM install, and again after any collection upgrade)
- Post-install manual steps (four CMsh scripts to add/remove kernel modules and rebuild ramdisk)

---

## Configuration Hierarchy

1. **Ansible defaults** → Read from `playbooks/ansible.cfg` (inventory, fact-gathering, etc.)
2. **Inventory** → Read from `inventory/hosts` or `inventory/localhost`
3. **Group vars** → Applied to all hosts in a group:
   - `playbooks/group_vars/head_node/cluster-*.yml` applied to `[head_node]` group
4. **Host vars** → Per-host overrides in `playbooks/host_vars/<hostname>.yml`

Variables flow: playbook defaults → group vars → host vars.

---

## Known Issues / TODOs

### Filename Typo
- `playbooks/post-deploy/cleanup-rhel-subsciptions.sh` has a typo in the filename: "subsciptions" (should be "subscriptions"). Documented in the header; correct in a future refactor to avoid breaking references to the script by name.

### Missing Shebang
- `playbooks/post-deploy/remove-cuda-default-image.sh` has no shebang line and minimal header. Fixed in documentation (shebang added, header expanded).

### Hardcoded Values
- `playbooks/10-prep-captureserver.yml` hardcodes `mysql_root_password: "Dellsvcs1"` in its vars block. Should reference `mysql_login_password` from `cluster-credentials.yml` instead.

### Vault Support Commented Out
- `playbooks/ansible.cfg` has vault support commented out (`#vault_password_file = .vault_pass`). Teams that encrypt the credentials file should uncomment this line and configure a vault password file.

---

## Inventory Targets

### `playbooks/inventory/hosts`
Remote host deployments. Examples:
- `[head_node]` — The target BCM head node (e.g., `rhel96-base`)
- `[image_target]` — The capture target for building a base image (e.g., a separate RHEL 9.x system)

Per-host settings live in `playbooks/host_vars/<hostname>.yml` (e.g., `host_vars/rhel96-base.yml` sets IP, SSH user, etc.).

### `playbooks/inventory/localhost`
Local control node execution. Used by:
- Playbook 20 (image capture on a local VM or container)
- Playbook 40 (patching the installed collection in-place)

---

## Code Style

- **Playbooks** use YAML 2.0 syntax. Variable names follow snake_case.
- **Shell scripts** use Bash 5+ features (e.g., `[[ ]]` test syntax, `+=` array append).
- **Comments** should explain the *why*, not the *what* (the code shows what it does).
- **Error handling** relies on Ansible's `ignore_errors`, `failed_when`, `changed_when` to suppress or highlight specific failures. Shell scripts use `set -e` to exit on error.

---

## Testing and Validation

- No automated tests exist yet (unit, integration, or end-to-end).
- Manual validation post-deploy uses `playbooks/post-deploy/validate-system-health-postdeploy.sh` to check BCM service state, disk usage, network connectivity, cmsh access, and timeserver configuration.
- RHEL 9.7 support has been tested with `brightcomputing.installer110==31.1.452+git66ec186` only.

---

## References

- [Main README](README.md)
- [RHEL 9.7 Guide](docs/rhel97-guide.md)
- [Bright Computing BCM Documentation](https://www.brightcomputing.com)
- [Ansible Collections User Guide](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html)
