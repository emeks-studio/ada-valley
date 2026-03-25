#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Build Alice Keys Disk Image for VirtualBox Testing
# ============================================================================
#
# WARNING: This script creates a disk image containing your age encryption key.
#          ONLY use this for VirtualBox testing with NON-PRODUCTION keys!
#
#          For production deployments, manually create a USB drive with
#          ext4 filesystem. See docs/external-keys-setup.md for details.
#
# ============================================================================

KEY_FILE="secrets/age-password.key"
OUTPUT_IMG="secrets/alice-keys.img"

echo "=================================================="
echo "Building Alice Keys Disk Image"
echo "=================================================="
echo ""

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Key file not found: $KEY_FILE"
    echo ""
    echo "Please ensure your age key exists at $KEY_FILE"
    exit 1
fi

# Warning prompt
echo "WARNING: This will create a disk image containing your age key at:"
echo "  $KEY_FILE"
echo ""
echo "This disk image should ONLY be used for VirtualBox testing!"
echo "Never use production keys with this process."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Create temporary directory for mount point
TEMP_MOUNT=$(mktemp -d)
trap "rm -rf $TEMP_MOUNT; [ -f '$OUTPUT_IMG' ] || true" EXIT

echo ""
echo "Creating disk image..."

# Create a 10MB raw disk image (more than enough for a key file)
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=10 status=none

# Format it with ext4 filesystem
mkfs.ext4 -q -L "ALICE_KEYS" "$OUTPUT_IMG"

# Mount the image
sudo mount -o loop "$OUTPUT_IMG" "$TEMP_MOUNT"

# Copy the key file
sudo cp "$KEY_FILE" "$TEMP_MOUNT/age-password.key"
sudo chmod 600 "$TEMP_MOUNT/age-password.key"

# Unmount
sudo umount "$TEMP_MOUNT"

echo ""
echo "=================================================="
echo "Success! Disk image created: $OUTPUT_IMG"
echo "=================================================="
echo ""
echo "To use with VirtualBox:"
echo "  1. Convert to VDI format (VirtualBox native):"
echo "     VBoxManage convertfromraw $OUTPUT_IMG secrets/alice-keys.vdi --format VDI"
echo ""
echo "  2. Attach as a second hard disk in VirtualBox VM settings:"
echo "     Settings → Storage → Add Hard Disk → secrets/alice-keys.vdi"
echo ""
echo "  3. Boot your NixOS ISO - it will auto-detect the ALICE_KEYS volume"
echo ""
echo "See docs/external-keys-setup.md for detailed instructions."
echo ""
