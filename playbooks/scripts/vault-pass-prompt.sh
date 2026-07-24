#!/bin/bash
#
# Vault password client for ansible.cfg (vault_password_file).
# Ansible executes this script and reads the vault password from stdout.
#
# Password sources, in order:
#   1. ANSIBLE_VAULT_PASSWORD environment variable (for CI / non-interactive runs)
#   2. Persisted ../.vault_pass file (set up once via setup-vault-password.sh;
#      survives new shells and the reboots after playbooks 10 and 30)
#   3. Interactive prompt on the terminal
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_PASS_FILE="${SCRIPT_DIR}/../.vault_pass"

if [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
    printf '%s' "${ANSIBLE_VAULT_PASSWORD}"
    exit 0
fi

if [[ -f "${VAULT_PASS_FILE}" ]]; then
    # Strip any trailing newline so it doesn't become part of the password.
    printf '%s' "$(cat "${VAULT_PASS_FILE}")"
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

echo "ERROR: No vault password available." >&2
echo "Run scripts/setup-vault-password.sh once to persist it to ${VAULT_PASS_FILE}," >&2
echo "or set the ANSIBLE_VAULT_PASSWORD environment variable for non-interactive runs." >&2
exit 1
