#!/bin/bash
# Removes NVIDIA/CUDA packages from a BCM image.
# Usage: ./remove-cuda-from-image.sh -i <imagename>
# Example: ./remove-cuda-from-image.sh -i default-no-cuda

set -e

usage() {
    echo "Usage: $0 -i <imagename>"
    echo "       $0 --image <imagename>"
    echo "Example: $0 -i default-no-cuda"
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

INSTALLROOT="/cm/images/${IMAGE_NAME}"

if [ ! -d "$INSTALLROOT" ]; then
    echo "Error: Image directory $INSTALLROOT does not exist"
    exit 1
fi

echo "Removing NVIDIA/CUDA packages from: $INSTALLROOT"

dnf remove -y nvidia-driver cuda-dcgm nvidia-fabricmanager --installroot="$INSTALLROOT"

dnf remove -y \
    nvidia-driver-cuda \
    nvidia-driver-cuda-libs \
    nvidia-driver-libs \
    kmod-nvidia-open-dkms \
    nvidia-kmod-common \
    nvidia-modprobe \
    nvidia-persistenced \
    nvidia-imex \
    libnvidia-\* \
    nvidia-libXNVCtrl\* \
    --installroot="$INSTALLROOT"

echo "Done. NVIDIA/CUDA packages removed from $INSTALLROOT"
