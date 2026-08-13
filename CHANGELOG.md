# Changelog

All notable changes to bcm-ansible are documented here.

---

## [v2026.8.1] — 2026-08-12

### Added
- `ansible.mariadb` collection added to `prereqs/requirements-collections.yml` and installed; replaces the non-functional `ansible.mysql` entry.
- `8021q` kernel module (VLAN tagging) added to `rhel97-updatemodules.txt` and documented in all RHEL 9.7 post-install references.
- Revision history table added to `docs/bcm-deployment-guide-direct.md`.
- Image-capture steps (playbooks 10 and 20) added to `readme-direct-method.md`; were previously missing, causing the BCM installer to fail on a missing image archive.

### Changed
- `30-prep-headnode.yml`: `ansible.mysql.mysql_user` → `ansible.mariadb.mariadb_user` — eliminates the community.mysql MariaDB deprecation warning.
- `rhel97-modulecleanup.txt` and `rhel97-startup.txt`: removed unsupported `commit -w` flag; both scripts now use plain `commit`.
- `docs/bcm-deployment-guide.md` and `docs/bcm-deployment-guide-direct.md`: vault password section corrected — documents all three sources (env var, persisted `.vault_pass`, interactive prompt) and removes the incorrect claim that no password is stored on disk.
- SSH key generation (controller method) is now manual (`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""`); the `00-ssh-keygen-controllernode.sh` wrapper is removed.
- DVD install (playbook 54) is now invoked directly via `ansible-playbook`; `run-54-install-bcm-dvd-local.sh` is retired to `.legacy`.
- `cleanup-deployed-image-with-cuda.sh`: rewritten to accept `-i/--image <imagename>` flag (was positional `$1`); NVIDIA/CUDA removal section extracted to separate script; old kernel tree removal renumbered to Step 5.
- `remove-cuda-default-image.sh` renamed to `remove-cuda-from-image.sh`: rewritten with shebang, proper header, `-i/--image <imagename>` flag, and explicit error handling.
- `README.md`: all controller-based deployment content removed; ISO/DVD install option removed from Step 6 — only the local yum repo method remains.

### Fixed
- Post-deploy scripts (`cleanup-deployed-image-with-cuda.sh`, `cleanup-rhel-subsciptions.sh`, `remove-cuda-from-image.sh`, `validate-system-health-postdeploy.sh`) marked executable.
- Dead link to `readme-controller-method.md` removed from `readme-direct-method.md`.
- Bullet-point prose (`- Extract bundle in /root`) moved out of a bash code block in `readme-direct-method.md`.
- `ansible.mysql` (non-existent collection) replaced with `ansible.mariadb` in `README.md` dependency list and both formal guides.

### Removed
- `playbooks/scripts/run-54-install-bcm-dvd-local.sh` — retired (kept as `.legacy` for reference).
- `playbooks/scripts/00-ssh-keygen-controllernode.sh` — SSH key generation is now a manual step.
- `readme-controller-method.md` — controller-method guide taken offline pending full end-to-end testing.
- Controller-based deployment content removed from `README.md` (Method 2 section, controller setup steps, `--hosts`/`--local` flag references).
- ISO/DVD install path removed from `README.md` Step 6; only the local CM repo install method is documented.

---

## [v2026.07] — 2026-07-24

### Added
- Vault password persistence via `playbooks/.vault_pass` (mode 600, gitignored) and `scripts/setup-vault-password.sh`. Eliminates repeated prompts across the multi-reboot deployment sequence.

---

## [v2026.07-stable] — 2026-07-18

### Added
- Direct-method deployment guide: `docs/bcm-deployment-guide-direct.md` (Markdown) and `docs/bcm-deployment-guide-direct.docx` (Word).
- Second tested `brightcomputing.installer110` collection version: `33.0.48+git940b822`.
- RHEL minor release lock enforcement in playbooks 10 and 30 — playbooks fail immediately if the release is not set to 9.6 or 9.7.
- Ansible Vault password prompting via `scripts/vault-pass-prompt.sh`; wired into `ansible.cfg` as `vault_password_file`.
- `cluster-license.yml` split out from `cluster-credentials.yml` so the product key and license identity remain plaintext and diffable.

### Changed
- Direct deployment method prioritized over controller-based in all documentation.
- `docs/bcm-deployment-guide.md` updated with release-lock requirement, vault handling, cm.repo automation, and second tested collection version.

---

## [v2026.05] — 2026-05-08

### Added
- RHEL 9.7 support via playbook 40 (`40-modify-installer-rhel97.yml`): patches the installed `brightcomputing.installer110` collection in place (adds distro entry, copies vars file, creates selection symlinks).
- `docs/rhel97-guide.md` — RHEL 9.7 patch details and post-install CMsh steps.
- Post-deploy CMsh scripts: `rhel97-updatemodules.txt`, `rhel97-modulecleanup.txt`, `rhel97-startup.txt`, `bcm-ansible-fix-node001.txt`.
- Post-deploy utilities: `validate-system-health-postdeploy.sh`, `cleanup-deployed-image-with-cuda.sh`, `remove-cuda-default-image.sh`, `cleanup-rhel-subsciptions.sh`.
- `.gitignore` — excludes `files/cm.repo`, `playbooks/.vault_pass`, and generated artifacts.
- Wrapper scripts updated to accept `--local` / `--hosts` / `--remote` flags for both deployment methods.

### Changed
- `cm.repo` removed from git tracking (contains credentials); `files/CM.REPO-goes-here` placeholder added.
- External IP and management network base address corrected in example host vars.

---

## [v2026.04] — 2026-04-28

### Added
- Initial repository structure and six-playbook deployment pipeline:
  - `10-prep-captureserver.yml` — prepare image-capture target
  - `20-grab-image.yml` — capture compute-node base image
  - `30-prep-headnode.yml` — prepare BCM head node (MariaDB, SELinux)
  - `40-modify-installer-rhel97.yml` — RHEL 9.7 collection patch
  - `54-install-bcm-dvd.yaml` — BCM install from DVD ISO
  - `55-install-bcm-cmrepo-local.yaml` — BCM install from local yum repo
- Wrapper scripts for each playbook in `playbooks/scripts/`.
- Inventory files: `inventory/hosts` (remote) and `inventory/localhost` (direct).
- Group vars: `cluster-settings.yml`, `cluster-credentials.yml`, `cluster-install-method.yml`.
- `prereqs/requirements-collections.yml` and `requirements-pip.txt`.
- `README.md` — initial project documentation.
- `docs/bcm-deployment-guide.md` and `docs/bcm-deployment-guide.docx`.
