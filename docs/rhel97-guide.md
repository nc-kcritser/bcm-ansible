# RHEL 9.7 Support Guide

## Background

The `brightcomputing.installer110` Ansible collection does not include RHEL 9.7 in its list of supported operating systems as of the versions this was tested with (`31.1.452+git66ec186` and `33.0.48+git940b822`). 

Playbook 40 (`40-modify-installer-rhel97.yml`) patches the locally installed collection in three ways to add RHEL 9.7 support:

1. **Add RHEL 9.7 to supported distros** — Adds `RedHat-9.7-x86_64` to the `support_distros` list in the collection's `roles/head_node/vars/main/main.yml`.
2. **Copy RHEL 9.6 vars to 9.7** — RHEL 9.7 uses the same package layout as RHEL 9.6. The playbook copies `os_RedHat_9.6_vars.yml` to `os_RedHat_9.7_vars.yml`.
3. **Create selection symlinks** — The playbook creates two symlinks:
   - `RHEL9u7-CM` → `RHEL9u6-CM`
   - `RHEL9u7-DIST` → `RHEL9u6-DIST`

---

## Version Requirement

**This patch has only been tested with `brightcomputing.installer110` versions `31.1.452+git66ec186` and `33.0.48+git940b822`** (as of 2026-07-18).

Playbook 40 checks the installed collection version and:
- Logs a success message if the version matches a tested version.
- Emits a warning if the version differs, noting that untested behavior may occur.

Do not assume newer collection versions are safe without re-testing.

---

## When to Run Playbook 40

Run playbook 40:

1. **Before deploying BCM on any RHEL 9.7 host** — Required once per control node.
2. **After any collection reinstall or upgrade** — The patch modifies the collection in-place. Reinstalling or upgrading the collection will revert the patch, so it must be re-applied.

Check the installed collection version with:

```bash
ansible-galaxy collection list brightcomputing.installer110
```

---

## Running the Patch

### Standard Run

```bash
cd playbooks/scripts
./run-40-modify-installer-rhel97.sh
```

### With Verbose Output

```bash
cd playbooks/scripts
./run-40-modify-installer-rhel97.sh -v
```

The playbook runs on `localhost` (the control node only). No inventory flag beyond the default is needed.

### Output

Successful run will show:
- Version check (pass or warning)
- Four file/symlink modifications in the collection directory
- No errors

---

## What Gets Modified

The playbook modifies these four paths inside the collection:

| Path | Change |
|---|---|
| `~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/vars/main/main.yml` | Adds `RedHat-9.7-x86_64` to the `support_distros` list |
| `~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/vars/os_RedHat_9.7_vars.yml` | New file copied from `os_RedHat_9.6_vars.yml` |
| `~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/files/buildmaster/selections/RHEL9u7-CM` | Symlink to `RHEL9u6-CM` |
| `~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/files/buildmaster/selections/RHEL9u7-DIST` | Symlink to `RHEL9u6-DIST` |

If you need to inspect or debug the patch, these are the locations to check.

---

## Post-Install RHEL 9.7 Steps

After BCM installation completes on RHEL 9.7, four manual CMsh steps must be run to finalize the deployment. These are provided as scripts in `playbooks/post-deploy/bcm-cmsh-scripts/`.

### Execution Order

Run these CMsh scripts in order:

1. **`rhel97-updatemodules.txt`** — Add kernel modules
2. **`rhel97-modulecleanup.txt`** — Remove legacy kernel modules
3. **`rhel97-startup.txt`** — Rebuild ramdisk

Additionally, if node IP configuration is needed:

4. **`bcm-ansible-fix-node001.txt`** — Fix node001 IP (if duplicate or incorrect)

### Running CMsh Scripts

Run each script with `cmsh -f`:

```bash
cd playbooks/post-deploy
cmsh -f bcm-cmsh-scripts/rhel97-updatemodules.txt -q -x
cmsh -f bcm-cmsh-scripts/rhel97-modulecleanup.txt -q -x
cmsh -f bcm-cmsh-scripts/rhel97-startup.txt -q -x
```

Or run each command interactively:

```bash
cmsh
cmsh> softwareimage
cmsh> use default-image
cmsh> kernelmodules
cmsh> add mpi3mr
cmsh> add bonding
cmsh> commit
```

### What Each Script Does

**`rhel97-updatemodules.txt`**
- Adds `mpi3mr` (Used for Support in PERC 965 cards)
- Adds `bonding` (network bonding support)

**`rhel97-modulecleanup.txt`**
- Removes legacy/conflicting SCSI and RAID drivers (3w-9xxx, aic7xxx, arcmsr, cciss, etc.) that do not exist in RHEL 9.7.
- Removes old network drivers
- Removes ext3 filesystem driver (deprecated in RHEL 9.7)

**`rhel97-startup.txt`**
- Rebuilds the ramdisk for the `default-image` after kernel module changes
- Uses `createramdisk` with wait flag (`commit -w`)

**`bcm-ansible-fix-node001.txt`** (optional)
- Navigates to `device > node001 > interfaces > bootif`
- Sets the boot interface IP to `172.16.0.101`
- Commits the change
- Only needed if node001 has an incorrect or duplicate IP

---

## Reverting the Patch

If you need to undo the patch and restore the collection to its original state:

```bash
ansible-galaxy collection install brightcomputing.installer110 --force
```

This reinstalls the collection from the repository, overwriting all patched files.

---

## Troubleshooting

### Collection version mismatch warning
The playbook warns if the installed version differs from the tested version. This is informational but should prompt you to re-test. You may proceed at your own risk, but breakage is possible.

### Patch appears not to apply
Confirm you ran playbook 40 and check the files listed in "What Gets Modified" exist and contain the expected changes.

### CMsh scripts fail
- Ensure CMsh is running and accessible: `cmsh -c "device; list"`
- Ensure you're running as root or with sufficient privileges
- Run the commands manually to see the actual error message

### After playbook 40, BCM installer still rejects RHEL 9.7
- Verify the RHEL 9.7 entry was added to `main.yml` (see "What Gets Modified" above)
- Re-run playbook 40 to ensure the patch applied correctly
- Check that the test playbook can see the patched collection: `ansible-playbook playbooks/40-modify-installer-rhel97.yml -vvv`

### Product key is locked during installation

If you see an error like:

```
TASK [brightcomputing.installer110.head_node : Request a new certificate] ****
fatal: [localhost]: FAILED! => {...
"content": "Product key ######-######-######-######-###### is locked.\nPlease go to the Bright Computing Customer Portal and submit a request to unlock your product key.\n", ...
}
```

**Solution:** Go to the [Bright Computing Customer Portal](https://customer.brightcomputing.com/unlock) and submit a request to unlock your product key. You cannot proceed with BCM installation until the key is unlocked.

---

## Testing the Patch

To verify the patch applied correctly without running a full BCM install:

```bash
# Check that RHEL 9.7 is in the support_distros list
grep -i "rhel.*9.7\|redhat.*9.7" ~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/vars/main/main.yml

# Check that the vars file exists
ls -la ~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/vars/os_RedHat_9.7_vars.yml

# Check that the symlinks exist
ls -la ~/.ansible/collections/ansible_collections/brightcomputing/installer110/roles/head_node/files/buildmaster/selections/RHEL9u7-*
```

All should show present files with no errors.

---

## References

- [Main README](../README.md)
- BCM 11.x Documentation
- [Collection location on localhost](https://docs.ansible.com/ansible/latest/user_guide/collections_on_ansible_version.html)
