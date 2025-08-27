# Initial Setup

## VM Shared Folder Setup

First, create a directory on the host to store shared data for this project.  
This directory will hold the Cardano node data accessed by the VM.

For the purpose of this guide, we'll use `/usr/share/ada-valley`.  
If you choose a different path, update it accordingly in all subsequent steps.

```sh
sudo mkdir -p /usr/share/ada-valley
sudo chmod -R 777 /usr/share/ada-valley
```

> ⚠️ Using `chmod 777` grants full access to every user on the
> host, not just the VM's user. A safer approach is to align the host and VM
> UID/GID and assign ownership with chown:\
> `sudo chown 1001:1001 /usr/share/ada-valley`

**📝 vars**:
Once you've created the shared folder, make sure to update
[vars.nix](../vars-template.nix) by setting the path under `vm.sharedFolder`
for use by the VM.

## Add SSH Public Key

The virtual machine accepts SSH connections only from authorized public keys.
To grant a user access, place their key in the [ssh-keys](../ssh-keys/)
directory.

- Create a file named after the corresponding VM system user.
- Add one public key per line inside the file.
- The listed keys define which users are permitted to log in via SSH under that
  username.

## Accessing Secrets

### Generate an age key

An [age](https://github.com/FiloSottile/age) key is needed to decrypt
[secrets](../secrets/keys.enc.yaml) and authenticate within the VM.

```sh
nix-shell -p age --run "age-keygen -o /usr/share/ada-valley/age-password.key"
# Example output:
# Public key: age1fxrjjr86wcvypgkhgq63rz0uv04c6ss0glqyxh4w88a4gdfv5sys2s6vmk
```

Append your generated public key to the `keys` section
in [.sops.yaml](../sops.yaml) and add it to the `age` key group.

```diff
keys:
+- &admin_<your_name> age1fxrjjr86wcvypgkhgq63rz0uv04c6ss0glqyxh4w88a4gdfv5sys2s6vmk
(...)
    - age:
      (...)
+     - *admin_<your_name>
```

Finally, ask an existing mantainer (someone already listed in `.sops.yaml`) to
re-encrypt the secrets so that your key is included.

> ℹ️ The `age-password.key` file is required to decrypt the secrets. Since it's
> stored in the shared folder (`/usr/share/ada-valley`), make sure to back it
> up before deleting or replacing that directory.

### Update the secrets file age keys

Whenever a new public key is added to the `.sops.yaml` file, the secrets file
must be updated so the new user can decrypt it. This ensures that all listed
recipients in the `age` key group have access to the encrypted secrets.

```sh
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops updatekeys ./secrets/keys.enc.yaml"
```

> ℹ️ Only users who already have access to the encrypted file can run this
> command successfully. New users must first have their public key added to
> `.sops.yaml` and request that someone with access re-encrypt the file to
> include their key.

### Edit the secrets file

To add new secrets or modify existing ones, open the encrypted file with the
following command:

```sh
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops ./secrets/keys.enc.yaml"
```

This will open the file in your default editor. When you save and exit, SOPS
will automatically re-encrypt the file for all recipients listed in the
`.sops.yaml` key groups.

### Encrypt the secrets file (one time per file)

When creating a secrets file for the first time, you must first create a
plaintext file with your secrets. Then run the following command to encrypt it:

```sh
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops -e ./secrets/keys.yaml > ./secrets/keys.enc.yaml"
```

Once encryption is complete, securely delete the original plaintext file:

```sh
shred -u ./secrets/keys.yaml
```

> ℹ️ After this initial encryption, all edits should be made directly on
> the encrypted file using SOPS, which ensures the automatic re-encryption.

### Decrypt the secrets file (plain text)

To view the contents of the encrypted file, run the following command:

```sh
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops -d ./secrets/keys.enc.yaml"
```
