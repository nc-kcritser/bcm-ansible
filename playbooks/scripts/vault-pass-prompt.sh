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

if [[ -e /dev/tty ]]; then
    read -rs -p "Ansible Vault password: " vault_pass < /dev/tty
    echo >/dev/tty
    printf '%s' "${vault_pass}"
    exit 0
fi

echo "ERROR: No terminal available to prompt for the vault password." >&2
echo "Set the ANSIBLE_VAULT_PASSWORD environment variable for non-interactive runs." >&2
exit 1
