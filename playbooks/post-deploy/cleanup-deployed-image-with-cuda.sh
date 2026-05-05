#!/bin/bash
# BCM Image Cleanup Script
# Removes unnecessary packages and bloat from Bright Cluster Manager default images
# Usage: ./bcm-image-cleanup.sh /path/to/image

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/image"
    echo "Example: $0 /cm/images/default-nocuda"
    exit 1
fi

IMGROOT="$1"

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
echo "Step 5: Removing NVIDIA driver packages..."
dnf_remove nvidia-driver nvidia-driver-cuda nvidia-driver-cuda-libs nvidia-driver-libs
dnf_remove kmod-nvidia-open-dkms nvidia-kmod-common nvidia-modprobe nvidia-persistenced nvidia-imex
dnf_remove libnvidia-\* nvidia-libXNVCtrl\*

echo ""
echo "Step 6: Cleaning package manager cache..."
dnf clean all --installroot=$IMGROOT

echo ""
echo "Step 8: Removing old kernel modules..."
CURRENT_KERNEL=$(ls -t $IMGROOT/usr/lib/modules/ 2>/dev/null | head -1)
if [ -n "$CURRENT_KERNEL" ]; then
    echo "[kernels] Keeping: $CURRENT_KERNEL"
    find $IMGROOT/usr/lib/modules -maxdepth 1 -type d ! -name "$CURRENT_KERNEL" ! -name "modules" -exec rm -rf {} \; 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "Image size summary:"
du -sh "$IMGROOT" 2>/dev/null || echo "Unable to calculate final size"
echo ""
echo "Note: Graphics libraries have been preserved."
echo "If you need to remove additional packages, check:"
echo "  du -sh $IMGROOT/usr/* | sort -h"
echo "  du -sh $IMGROOT/* | sort -h"