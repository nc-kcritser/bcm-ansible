#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

INVENTORY="inventory/localhost"
VERBOSE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Prepare a node for image capture. Can target local machine or remote host.

OPTIONS:
    --local             Use localhost inventory (default)
    --hosts, --remote   Use remote hosts inventory
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    # Prepare local machine
    $(basename "$0") --local

    # Prepare remote host
    $(basename "$0") --hosts

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

echo "Running 10-prep-captureserver with inventory: $INVENTORY"

cd "$ANSIBLE_DIR"
ansible-playbook $VERBOSE -i "$INVENTORY" playbooks/10-prep-captureserver.yml
