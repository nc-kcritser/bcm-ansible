#!/bin/bash
#
# One-time prereq: persists the Ansible Vault password to playbooks/.vault_pass
# (mode 600, gitignored) so every subsequent playbook run picks it up
# automatically via vault-pass-prompt.sh — including across the reboots
# after playbooks 10 and 30, and in fresh shells. Nothing to export, nothing
# to re-enter.
#
# Run once, from anywhere:
#   scripts/setup-vault-password.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOKS_DIR="$(dirname "${SCRIPT_DIR}")"
VAULT_PASS_FILE="${PLAYBOOKS_DIR}/.vault_pass"
CREDENTIALS_FILE="group_vars/head_node/cluster-credentials.yml"

read -rs -p "Ansible Vault password: " vault_pass
echo
read -rs -p "Confirm: " vault_pass_confirm
echo

if [[ "${vault_pass}" != "${vault_pass_confirm}" ]]; then
    echo "ERROR: passwords did not match. Nothing saved." >&2
    exit 1
fi

if command -v ansible-vault >/dev/null 2>&1 && [[ -f "${PLAYBOOKS_DIR}/${CREDENTIALS_FILE}" ]]; then
    if ! ANSIBLE_VAULT_PASSWORD="${vault_pass}" ansible-vault view \
            --vault-password-file "${SCRIPT_DIR}/vault-pass-prompt.sh" \
            "${PLAYBOOKS_DIR}/${CREDENTIALS_FILE}" >/dev/null 2>&1; then
        echo "ERROR: that password does not decrypt ${CREDENTIALS_FILE}. Nothing saved." >&2
        exit 1
    fi
fi

umask 077
printf '%s' "${vault_pass}" > "${VAULT_PASS_FILE}"
chmod 600 "${VAULT_PASS_FILE}"

echo "Vault password verified and saved to ${VAULT_PASS_FILE} (mode 600, gitignored)."
