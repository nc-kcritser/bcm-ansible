#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

INVENTORY="inventory/localhost"
VERBOSE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Modify BCM installer for RHEL 9.7 support. Runs locally on controller node.

OPTIONS:
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    # Modify installer with default settings
    $(basename "$0")

    # With verbose output
    $(basename "$0") -v
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
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

echo "Running 40-modify-installer-rhel97 (local controller node only)"

cd "$ANSIBLE_DIR"
ansible-playbook $VERBOSE -i "$INVENTORY" 40-modify-installer-rhel97.yml
