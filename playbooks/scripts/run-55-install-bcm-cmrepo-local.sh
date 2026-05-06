#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

INVENTORY="inventory/localhost"
VERBOSE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Install BCM 11.x from local yum repository. Can target local (direct) or remote (controller) head node.

OPTIONS:
    --local             Use localhost inventory - run on this system (default, direct method)
    --hosts, --remote   Use remote hosts inventory - run on target head node (controller method)
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    # Install on local system (direct method)
    $(basename "$0") --local

    # Install on remote head node via controller (controller method)
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

echo "Running 55-install-bcm-cmrepo-local with inventory: $INVENTORY"
echo ""

cd "$ANSIBLE_DIR"
ansible-playbook $VERBOSE \
  -i "$INVENTORY" \
  55-install-bcm-cmrepo-local.yaml