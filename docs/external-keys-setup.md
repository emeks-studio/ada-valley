# Using External Keys with NixOS ISO

This NixOS ISO configuration is designed to load sensitive keys (specifically the age encryption key for sops-nix) from an external volume rather than embedding them in the ISO image. This provides better security for production deployments while still being testable with VirtualBox.

## How It Works

The system looks for a volume labeled `ALICE_KEYS` containing an `age-password.key` file. During system activation, it will:

1. Check if `/mnt/keys/age-password.key` exists (auto-mounted from `ALICE_KEYS` volume)
2. Copy the key to `/persistent/secrets/age-password.key` if found
3. Continue booting with warnings if not found (sops-encrypted secrets won't be available)

## Testing with VirtualBox

### Step 1: Create the Keys Volume

**WARNING: Only use NON-PRODUCTION keys for this step!**

The keys ISO build process requires you to manually run a script in a Nix development environment. This ensures you consciously choose to include your keys, rather than accidentally embedding production secrets.

Enter the keys build environment:

```bash
nix develop .#keys
```

Then run the build script:

```bash
./build-alice-keys-disk.sh
```

This will:
1. Prompt you to confirm the operation
2. Create `secrets/alice-keys.img` (a virtual disk image) containing your `secrets/age-password.key`
3. **Warning:** This disk image will contain your key in plaintext - only use for testing!
4. The disk image is automatically gitignored for security

### Step 2: Build the Main ISO

```bash
nix build .#bichota-iso --override-input varsFilePath path:./vars.nix
```

The ISO will be available at `./result/iso/*.iso`

### Step 3: Configure VirtualBox VM (Before First Boot)

1. Create a new VM in VirtualBox
2. **Before starting the VM**, go to **Settings** → **Storage**
3. Attach the main NixOS ISO:
   - Under "Controller: IDE" or "Controller: SATA", click the empty optical drive slot
   - Click the disc icon → **Choose a disk file...**
   - Select `./result/iso/*.iso` (the main NixOS ISO)
4. Attach the keys disk image:
   - Click the **"Add hard disk"** icon (+ icon next to Controller)
   - Click **"Add"** → Select `secrets/alice-keys.img`
   - Click **"Choose"**
5. Click **OK** to save settings
6. **Now start the VM**

The system will automatically detect the `ALICE_KEYS` volume during boot and copy the key.

### Step 4: Verify Key Loading

After the system activates, check the logs:

```bash
journalctl -b | grep "age key"
```

You should see: "Found age key on external volume, copying to persistent storage"

## Production Deployment

For production use, create a USB drive with ext4 formatting and the `ALICE_KEYS` label.

### USB Drive Setup

1. Format a USB drive with ext4 and set the volume label:
   ```bash
   sudo mkfs.ext4 -L ALICE_KEYS /dev/sdX1
   ```
2. Mount and copy your key:
   ```bash
   sudo mount /dev/sdX1 /mnt
   sudo cp age-password.key /mnt/
   sudo chmod 600 /mnt/age-password.key
   sudo umount /mnt
   ```
3. Insert the USB drive before booting the target machine
4. **Security:** Store the USB drive in a secure location after the system boots and copies the key

**Note:** The disk image build script (`build-alice-keys-disk.sh`) is intended for VirtualBox testing with non-production keys only. For production, use a removable USB drive as described above.

## Security Considerations

### What This Approach Provides

- **Separation of secrets**: Keys are never baked into the ISO
- **Physical security**: Keys require physical access to the USB/disk
- **Auditability**: ISO can be shared/audited without exposing secrets
- **Revocability**: Remove USB drive after boot to prevent key extraction

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
