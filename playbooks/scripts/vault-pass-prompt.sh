#!/bin/bash
#
# Vault password client for ansible.cfg (vault_password_file).
# Ansible executes this script and reads the vault password from stdout.
#
# Password sources, in order:
#   1. ANSIBLE_VAULT_PASSWORD environment variable (for CI / non-interactive runs)
#   2. Interactive prompt on the terminal
#
set -euo pipefail

if [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
    printf '%s' "${ANSIBLE_VAULT_PASSWORD}"
    exit 0
fi

# -e /dev/tty is not enough: the node exists even when there is no
# controlling terminal, so test that it can actually be opened.
if ( : < /dev/tty ) 2>/dev/null; then
    read -rs -p "Ansible Vault password: " vault_pass < /dev/tty
    echo >&2
    printf '%s' "${vault_pass}"
    exit 0
fi

echo "ERROR: No terminal available to prompt for the vault password." >&2
echo "Set the ANSIBLE_VAULT_PASSWORD environment variable for non-interactive runs." >&2
exit 1
