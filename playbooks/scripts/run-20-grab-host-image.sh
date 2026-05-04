#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

INVENTORY="inventory/localhost"
IMAGE_FILENAME=""
VERBOSE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Grab/archive a system image. Can target local machine or remote host.

OPTIONS:
    --local             Use localhost inventory (default)
    --hosts, --remote   Use remote hosts inventory
    -f, --filename      Image filename (e.g., RHEL9u6.tar.gz)
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    # Grab image from local machine with default filename
    $(basename "$0") --local

    # Grab image from remote host with custom filename
    $(basename "$0") --remote -f my-image.tar.gz

    # With verbose output
    $(basename "$0") --local -v
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
        -f|--filename)
            IMAGE_FILENAME="$2"
            shift 2
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

echo "Running 20-grab-image with inventory: $INVENTORY"

cd "$ANSIBLE_DIR"

# Build ansible-playbook command
ANSIBLE_CMD="ansible-playbook $VERBOSE -i $INVENTORY 20-grab-image.yml"

# Add extra variables if specified
if [[ -n "$IMAGE_FILENAME" ]]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e image_filename=$IMAGE_FILENAME"
fi

eval "$ANSIBLE_CMD"

