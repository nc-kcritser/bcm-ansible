#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

INVENTORY="inventory/localhost"
VERBOSE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Prepare RHEL 9.x head node for BCM installation. Can target local or remote host.

OPTIONS:
    --local             Use localhost inventory (default)
    --hosts, --remote   Use remote hosts inventory
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    # Prepare local head node
    $(basename "$0") --local

    # Prepare remote head node
    $(basename "$0") --remote

    # With verbose output
    $(basename "$0") --remote -v
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            INVENTORY="inventory/localhost"
            shift
            ;;
        --hosts|--remote)
            INVENTORY="inventory/hosts"
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "Running 30-prep-headnode with inventory: $INVENTORY"

cd "$ANSIBLE_DIR"
ansible-playbook $VERBOSE -i "$INVENTORY" 30-prep-headnode.yml
