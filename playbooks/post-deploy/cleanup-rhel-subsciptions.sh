#!/bin/bash
# Red Hat Subscription Cleanup Script
# Removes Red Hat subscriptions from nodes and BCM images
# Usage: ./redhat-subscription-cleanup.sh [/path/to/image]
# If no image path provided, cleans the local system

set -e

if [ -z "$1" ]; then
    # Clean local system
    echo "=========================================="
    echo "Red Hat Subscription Cleanup"
    echo "=========================================="
    echo "Target: Local system"
    echo ""
    
    echo "Unregistering system..."
    subscription-manager unregister || true
    
    echo "Cleaning subscription cache..."
    subscription-manager clean || true
    
    echo ""
    echo "=========================================="
    echo "Cleanup complete!"
    echo "=========================================="
else
    # Clean image
    IMGROOT="$1"
    
    if [ ! -d "$IMGROOT" ]; then
        echo "Error: Image directory $IMGROOT does not exist"
        exit 1
    fi
    
    echo "=========================================="
    echo "Red Hat Subscription Cleanup"
    echo "=========================================="
    echo "Target image: $IMGROOT"
    echo ""
    
    echo "Unregistering image..."
    subscription-manager unregister --installroot=$IMGROOT || true
    
    echo "Cleaning subscription cache..."
    subscription-manager clean --installroot=$IMGROOT || true
    
    echo ""
    echo "=========================================="
    echo "Cleanup complete!"
    echo "=========================================="
fi