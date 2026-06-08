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

**For Wired Ethernet (eth1):**
```bash
nix build .#bichota-iso --override-input varsFilePath path:./vars.nix
```

**For WiFi Networks (Alternative):**
```bash
nix build .#bichota-iso-wifi --override-input varsFilePath path:./vars.nix
```

The ISO will be available at `./result/iso/*.iso`

**WiFi Configuration:** If you use the WiFi ISO, you'll need to configure your network after booting. See [Configuring WiFi](#configuring-wifi-wifi-iso-only) below.

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

### Configuring WiFi (WiFi ISO Only)

If you built the WiFi-enabled ISO (`bichota-iso-wifi`), you'll need to configure your WiFi network after booting. The WiFi credentials are NOT embedded in the ISO for security reasons.

#### Method 1: Using the Helper Script (Recommended)

After booting from the WiFi ISO, log in as `alice` and run:

```bash
sudo setup-wifi
```

The script will:
1. Scan for available networks
2. Prompt you for your WiFi SSID (network name)
3. Prompt you for your WiFi password
4. Connect automatically and display your IP address
5. Save the configuration for future boots (persisted across reboots)

**Note:** The cardano-node service starts automatically and waits for network connectivity. Once WiFi connects, the node will start automatically. If you experience any issues, you can manually restart the service:

```bash
sudo systemctl restart cardano-node
```

#### Method 2: Manual Configuration with wpa_cli

If you prefer manual configuration:

```bash
# Scan for available networks
sudo wpa_cli scan
sleep 2
sudo wpa_cli scan_results

# Add a new network
sudo wpa_cli add_network
# This returns a network ID (usually 0)

# Configure the network (replace 0 with your network ID if different)
sudo wpa_cli set_network 0 ssid '"YourNetworkName"'
sudo wpa_cli set_network 0 psk '"YourPassword"'

# Enable and save the network
sudo wpa_cli enable_network 0
sudo wpa_cli save_config

# Check connection status
sudo wpa_cli status

# Verify you have an IP address
ip addr show
```

The WiFi configuration is automatically persisted to `/persistent/etc/wpa_supplicant.conf`, so you only need to configure it once. On subsequent boots, the system will automatically reconnect to your saved network.

## Installing NixOS to Physical Hardware (Permanent Installation)

This section describes how to perform a **permanent installation** of NixOS to your internal disk. This is the recommended approach for production Cardano nodes.

### Prerequisites

Before installation, ensure you have:

1. **Two USB Drives:**
   - `ALICE_KEYS` USB drive (with encryption keys)
   - Bootable ISO USB drive (created in previous steps)

2. **Target Hardware:**
   - Computer/server with at least 16GB RAM
   - At least 250GB internal storage (500GB+ recommended for mainnet)
   - Network connectivity (Ethernet or WiFi)
   - UEFI boot support (recommended)

3. **Important Warning:**
   ⚠️ This installation will **format and erase your internal disk**. Back up any important data first!

### Installation Steps

#### 1. Boot from the ISO

**Insert both USB drives:**
- Plug in the `ALICE_KEYS` USB drive
- Plug in the bootable ISO USB drive

**Boot from the ISO USB:**
1. Power on the machine
2. Enter BIOS/UEFI settings (usually F2, F7, F12, DEL, or ESC during boot)
3. Set boot priority to boot from the ISO USB drive
4. Save and exit BIOS/UEFI

#### 2. Initial Setup

After the system boots:

1. **Login as alice** (using the password from your `ALICE_KEYS` USB)

2. **Configure WiFi** (if using WiFi ISO):
   ```bash
   sudo setup-wifi
   ```

3. **Verify network connectivity:**
   ```bash
   ping -c 3 google.com
   ```

#### 3. Inspect Current Disk Layout

Before partitioning, inspect your disk to understand the current layout:

```bash
# Show all block devices and partitions
lsblk -f

# Show detailed partition information
sudo fdisk -l

# Identify your target disk (e.g., /dev/sda, /dev/nvme0n1, etc.)
```

**Understanding the output:**

- **NTFS partitions** → Windows installation present
- **ext4/btrfs partitions** → Existing Linux installation
- **vfat EFI partition** → UEFI boot partition

**Example output:**
```
NAME   FSTYPE LABEL       SIZE
sda                      500G
├─sda1 vfat   EFI         100M
├─sda2 ntfs   Windows     200G
└─sda3 ext4   OldLinux    200G
```

⚠️ **Identify your target disk** (e.g., `/dev/sda`) - all data on this disk will be erased!

#### 4. Partition the Disk

We'll create a simple partition layout with EFI boot partition and root partition.

**For this example, we'll assume `/dev/sda` is your target disk. Replace with your actual disk!**

```bash
# DANGER: This will erase all data on /dev/sda!
sudo fdisk /dev/sda
```

**Inside fdisk, create partitions:**

1. Type `g` to create a new GPT partition table (erases all existing partitions)
2. Type `n` for new partition (EFI boot partition):
   - Partition number: `1` (default)
   - First sector: (default, press Enter)
   - Last sector: `+512M` (512MB for EFI)
3. Type `t` to change partition type:
   - Partition number: `1`
   - Type: `1` (EFI System)
4. Type `n` for new partition (root partition):
   - Partition number: `2` (default)
   - First sector: (default, press Enter)
   - Last sector: (default, uses remaining space, press Enter)
5. Type `w` to write changes and exit

**Verify partitions were created:**
```bash
lsblk /dev/sda
```

You should see:
```
NAME   SIZE TYPE
sda    500G disk
├─sda1 512M part  ← EFI boot
└─sda2 499G part  ← Root partition
```

#### 5. Format the Partitions

```bash
# Format EFI partition as FAT32
sudo mkfs.fat -F 32 -n BOOT /dev/sda1

# Format root partition as ext4
sudo mkfs.ext4 -L nixos /dev/sda2
```

**For NVMe drives**, partition names are different:
```bash
# NVMe example:
sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

#### 6. Mount the Filesystems

```bash
# Mount root partition
sudo mount /dev/sda2 /mnt

# Create and mount EFI partition
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot

# Verify mounts
lsblk -f | grep -E "sda|mnt"
```

#### 7. Generate NixOS Configuration

```bash
# Generate initial configuration
sudo nixos-generate-config --root /mnt

# This creates:
# /mnt/etc/nixos/configuration.nix
# /mnt/etc/nixos/hardware-configuration.nix
```

**Note:** The ISO includes a complete example configuration at `/etc/nixos/configuration-scaffold.nix` which contains all the cardano-node setup, WiFi support, and persistence configuration. We'll use this in the next step.

#### 8. Copy Your Configuration Files

Now we need to replace the generated configuration with your ada-valley configuration:

```bash
# The ISO includes an example configuration at /etc/nixos/configuration-scaffold.nix
# This is the full configuration used to build the ISO

# Copy it as your base configuration
sudo cp /etc/nixos/configuration-scaffold.nix /mnt/etc/nixos/

# Edit the main configuration.nix to use it
sudo tee /mnt/etc/nixos/configuration.nix > /dev/null <<'EOF'
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration-scaffold.nix  # The ISO's full configuration
  ];

  # Enable bootloader for permanent installation
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Note: /persistent is just a directory on the root filesystem (/)
  # The impermanence module (from configuration-scaffold.nix) handles persistence
  # No separate filesystem mount needed - data persists because root is on disk
  
  # Optional: You can override settings from configuration-scaffold.nix here
  # For example, change network settings, add users, etc.
}
EOF
```

#### 9. Install NixOS

```bash
# Install NixOS to /mnt
sudo nixos-install

# You'll be prompted to set a root password - set it!
```

This process will:
- Install all packages
- Set up the bootloader
- Configure the system according to your configuration

**This may take 10-30 minutes depending on your internet connection.**

#### 10. Reboot into New System

```bash
# Reboot the system
sudo reboot
```

**After reboot:**
1. Remove the ISO USB drive (but keep ALICE_KEYS plugged in)
2. System should boot from the internal disk
3. Login as `alice`

#### 11. Post-Installation Verification

After booting into your new permanent installation:

```bash
# Verify you're running from internal disk (not ISO)
df -h | grep "^/dev"

# Check that /persistent is mounted to real disk
findmnt /persistent

# Verify cardano-node is running
sudo systemctl status cardano-node

# Check cardano-node data directory
ls /persistent/cardano-node/

# Monitor blockchain sync progress
cardano-cli query tip --testnet-magic 1

# Verify time synchronization (critical for Cardano)
chronyc tracking

# Check network connectivity
ip addr show
```

#### 12. Ongoing Maintenance

**To update your NixOS configuration:**

1. Edit `/etc/nixos/configuration.nix` or `/etc/nixos/vars.nix`
2. Rebuild the system:
   ```bash
   sudo nixos-rebuild switch
   ```

**To backup your stake pool keys:**
- Keep the `ALICE_KEYS` USB drive in a secure location
- Consider creating encrypted backups of `/persistent/secrets/`
- Store backups in multiple secure locations

**To monitor your node:**
```bash
# View cardano-node logs
sudo journalctl -u cardano-node -f

# Check disk space (blockchain grows over time)
df -h /persistent

# Monitor system resources
htop
```

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
