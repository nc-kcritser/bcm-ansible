#!/bin/bash
# BCM Image Cleanup Script
# Removes firmware, desktop, audio, NVIDIA/CUDA packages, and old kernel trees from a BCM image.
# Usage: ./cleanup-deployed-image-with-cuda.sh -i <imagename>
# Example: ./cleanup-deployed-image-with-cuda.sh -i default-nocuda

set -e

usage() {
    echo "Usage: $0 -i <imagename>"
    echo "       $0 --image <imagename>"
    echo "Example: $0 -i default-nocuda"
    exit 1
}

IMAGE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: image name is required."
    usage
fi

IMGROOT="/cm/images/${IMAGE_NAME}"

if [ ! -d "$IMGROOT" ]; then
    echo "Error: Image directory $IMGROOT does not exist"
    exit 1
fi

echo "=========================================="
echo "BCM Image Cleanup Script"
echo "=========================================="
echo "Target image: $IMGROOT"
echo ""

# Function to run dnf commands with installroot
dnf_remove() {
    echo "[dnf] Removing: $@"
    dnf remove -y "$@" --installroot=$IMGROOT 2>&1 | grep -E "(Removed|Complete|error)" || true
}

# Function to remove directories
safe_rm() {
    if [ -d "$1" ]; then
        echo "[rm] Removing: $1"
        rm -rf "$1"
    fi
}

echo ""
echo "Step 1: Removing firmware packages..."
dnf_remove iwl\*-firmware

echo ""
echo "Step 2: Removing GUI/desktop packages..."
dnf_remove firefox evince\* ghostscript\* totem-pl-parser

echo ""
echo "Step 3: Removing audio/sound packages..."
dnf_remove cups\* pipewire\* wireplumber\* alsa-lib flac-libs libsndfile libvorbis opus gsm sound-theme-freedesktop

echo ""
echo "Step 4: Removing other unnecessary packages..."
dnf_remove colord\* libwacom\* ModemManager-glib bluez-libs flatpak\*

echo ""
echo "Step 5: Removing old kernel modules..."
CURRENT_KERNEL=$(ls -t $IMGROOT/usr/lib/modules/ 2>/dev/null | head -1)
if [ -n "$CURRENT_KERNEL" ]; then
    echo "[kernels] Keeping: $CURRENT_KERNEL"
    find $IMGROOT/usr/lib/modules -maxdepth 1 -type d ! -name "$CURRENT_KERNEL" ! -name "modules" -exec rm -rf {} \; 2>/dev/null || true
fi

echo ""
echo "Step 6: Cleaning package manager cache..."
dnf clean all --installroot=$IMGROOT

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "Image size summary:"
du -sh "$IMGROOT" 2>/dev/null || echo "Unable to calculate final size"
