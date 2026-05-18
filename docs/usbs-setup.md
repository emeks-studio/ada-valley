# Preparing the USB Drives

This NixOS ISO configuration is designed to load sensitive keys (specifically the age encryption key for sops-nix) from an external USB volume rather than embedding them in the ISO image. This provides better security for production deployments and can be tested realistically with VirtualBox using USB passthrough.

## How It Works

The system looks for a volume labeled `ALICE_KEYS` containing an `age-password.key` file. During system activation, it will:

1. Check if `/mnt/keys/age-password.key` exists (auto-mounted from `ALICE_KEYS` volume)
2. Copy the key to `/persistent/secrets/age-password.key` if found
3. Continue booting with warnings if not found (sops-encrypted secrets won't be available)

The configuration uses `/dev/disk/by-label/ALICE_KEYS` which automatically detects any block device with that label, whether it's a physical USB drive, VirtualBox USB passthrough, or any other storage device.

## Setup

You will need **TWO USB drives** for deployment:
- **USB Drive 1**: `ALICE_KEYS` - Contains the age encryption key
- **USB Drive 2**: Bootable ISO - Contains the NixOS live system

**WARNING: Only use NON-PRODUCTION keys for testing!**

### Step 1: Prepare the ALICE_KEYS USB Drive (Encryption Key)

1. Insert your USB drive and identify its device path:
   ```bash
   lsblk
   # Look for your USB drive (e.g., /dev/sdb)
   ```

2. Format with ext4 and set the `ALICE_KEYS` label:
   ```bash
   # WARNING: This will erase all data on the partition!
   sudo mkfs.ext4 -L ALICE_KEYS /dev/sdX1  # Replace X with your device letter
   ```

3. Mount and copy your age key:
   ```bash
   # Create a temporary mount directory
   MOUNT_DIR=$(mktemp -d)
   
   # Mount the USB drive
   sudo mount /dev/sdX1 "$MOUNT_DIR"
   
   # Copy your age key
   sudo cp /path/to/your/age-password.key "$MOUNT_DIR/"
   sudo chmod 600 "$MOUNT_DIR/age-password.key"
   
   # Unmount when done
   sudo umount "$MOUNT_DIR"
   
   # Clean up the temporary directory
   rmdir "$MOUNT_DIR"
   ```

4. Your `ALICE_KEYS` USB drive is now ready for both testing and production use

### Step 2: Create Bootable USB Drive (NixOS Live System)

To boot the ISO on physical hardware, you need to write it to a second USB drive.

#### Build the ISO

```bash
nix build .#bichota-iso --override-input varsFilePath path:./vars.nix
```

The ISO will be available at `./result/iso/*.iso`

#### Find Your Second USB Drive

```bash
lsblk
# Identify your USB drive (e.g., /dev/sdc)
# ⚠️  WARNING: Make sure you select the CORRECT device - it will be erased!
```

#### Unmount the USB Drive (if auto-mounted)

```bash
# Check if any partitions are mounted
mount | grep sdX  # Replace X with your device letter

# Unmount all partitions if needed
sudo umount /dev/sdX1  # Repeat for sdX2, sdX3, etc. if needed
```

#### Write the ISO to USB

**Method 1: Using `dd` (Traditional method)**

```bash
# Write the ISO to the USB drive
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
# Replace X with your device letter (e.g., /dev/sdc)

# Important:
# - Use the whole device (/dev/sdc), NOT a partition (/dev/sdc1)
# - bs=4M: Block size for faster writing
# - status=progress: Shows progress during write
# - conv=fsync: Ensures all data is written before completion
```

**Method 2: Using `cp` (Simpler, works for UEFI systems)**

```bash
# Copy the ISO directly to the device
sudo cp result/iso/nixos-*.iso /dev/sdX

# Ensure all data is written
sudo sync

# Safely eject
sudo eject /dev/sdX
```

#### Verify and Eject

```bash
# Safely eject the USB drive
sudo eject /dev/sdX
```

Your bootable USB drive is now ready! When deploying to physical hardware, plug in **both USB drives**:
- The `ALICE_KEYS` USB (encryption key)
- The bootable ISO USB (NixOS system)

## Testing with VirtualBox (Alternative to Physical Hardware)

If you want to test the ISO in a VM before deploying to physical hardware, you can use VirtualBox with USB passthrough. This allows you to test with your `ALICE_KEYS` USB drive just like in production.

#### Install VirtualBox Extension Pack (Required for USB 2.0/3.0)

USB 2.0/3.0 passthrough requires the VirtualBox Extension Pack.

**On NixOS**, add this to your `configuration.nix`:
```nix
virtualisation.virtualbox.host.enableExtensionPack = true;
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

**On other systems**, download and install from: https://www.virtualbox.org/wiki/Downloads

Verify installation:
```bash
VBoxManage list extpacks
# Should show: Extension Packs: 1
```

**Add your user to vboxusers group:**
```bash
sudo usermod -aG vboxusers $USER
# Log out and back in for changes to take effect
```

Verify group membership:
```bash
groups | grep vboxusers
```

#### Create and Configure VirtualBox VM

1. **Create a new VM** in VirtualBox (Linux, NixOS, 64-bit)

2. **Configure Storage** (Settings → Storage):
   - Under "Controller: IDE" or "Controller: SATA", click the empty optical drive slot
   - Click the disc icon → **Choose a disk file...**
   - Select `./result/iso/*.iso` (the main NixOS ISO)
   - Click **OK**

3. **Configure USB** (Settings → USB):
   - Enable **USB Controller** (check the box)
   - Select **USB 2.0 (EHCI) Controller** or **USB 3.0 (xHCI) Controller**
   - Click the **"Add USB filter"** icon (+ with USB symbol on the right side)
   - **Plug in your USB drive** if not already plugged in
   - Select your USB drive from the dropdown device list
   - This creates a filter that auto-attaches the USB when the VM starts
   - Click **OK**

   **Note:** USB drives are NOT added through "Storage" settings! The USB passthrough happens through the USB controller and device filters.

4. **Start the VM** with the USB drive plugged in
   - The USB drive will disappear from your host (VM has exclusive access)
   - Inside the VM, run `lsblk` to verify the USB appears (e.g., as `/dev/sdb`)

### Step 3: Verify Key Loading

After the system boots and activates, check the logs:

```bash
journalctl -b | grep "age key"
```

You should see:
```
Found age key on external volume, copying to persistent storage
```

You can also verify the mount:
```bash
# Check if USB is detected
lsblk -o NAME,LABEL,MOUNTPOINT

# Should show something like:
# sdb1  ALICE_KEYS  /mnt/keys

# Verify the key was copied
ls -la /persistent/secrets/age-password.key
```

### Troubleshooting VirtualBox USB Passthrough

**USB device not appearing in VM:**
- Ensure VirtualBox Extension Pack is installed
- Verify you're in the `vboxusers` group: `groups | grep vboxusers`
- Log out and back in after adding yourself to the group
- Make sure the USB filter is active (should be checked in Settings → USB)

**Permission denied errors:**
- Check that your user owns the USB device: `ls -la /dev/bus/usb/*/*`
- Ensure udev rules are correct for your system

**VM won't start with USB filter enabled:**
- Try removing the USB filter, starting the VM, then attaching USB manually:
  - VM menu → Devices → USB → Select your device

## Production Deployment

For production use, follow the same USB drive preparation steps above, but with your production age key.

### Production USB Drive Setup

1. Use a dedicated USB drive for production (don't reuse testing drives)
2. Format with ext4 and label as `ALICE_KEYS` (see "Preparing the USB Drive" above)
3. Copy your **production** age key to the drive
4. Insert the USB drive before booting the target machine
5. **Security:** Remove and store the USB drive in a secure location after the system boots and copies the key

### Why USB Drives Work for Both Testing and Production

The NixOS configuration uses device-agnostic mounting via `/dev/disk/by-label/ALICE_KEYS`, which means:
- The same USB drive works in both physical hardware and VirtualBox (via USB passthrough)
- No configuration changes needed between testing and production
- The USB drive appears as a standard block device regardless of environment

## Security Considerations

### What This Approach Provides

- **Separation of secrets**: Keys are never baked into the ISO
- **Physical security**: Keys require physical access to the USB/disk
- **Auditability**: ISO can be shared/audited without exposing secrets
- **Revocability**: Remove USB drive after boot to prevent key extraction
- **Read-only mount**: USB is mounted read-only (`ro`) to prevent tampering

### What This Approach Does NOT Provide

- **Encrypted key storage**: The key on the USB is stored in plaintext
- **Boot-time authentication**: No password/PIN required to use the key
- **Secure deletion**: Keys are copied to persistent storage

### Recommendations for Production

1. **Encrypt the USB drive**: Use LUKS encryption on the USB containing keys
2. **Restrict physical access**: Store USB in a secure location after deployment
3. **Use TPM integration**: Consider TPM-sealed keys for unattended boot
4. **Rotate keys regularly**: Follow your security policy for key rotation
5. **Monitor key access**: Check logs for unauthorized key access attempts
