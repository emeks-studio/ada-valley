# Package

## View available options

The flake provides a `help` command to list the options available in the
package:

```sh
nix run .#help
```

## Build the VM

To build the NixOS VM:

```sh
nix build .#nixosConfigurations.nixos-vm.config.system.build.vm --override-input varsFilePath path:./vars.nix
```

## Start the VM

To preview how the VM will be started without actually running it:

```sh
nix run .#show
```

To start the VM:

```sh
nix run .#start-vm
```

Or simply run the default target:

```sh
nix run .
```

## Access the VM

You can interact with the VM either directly or via SSH.

### Direct access

Once the VM is started, it will prompt for a username and password.

Credentials:

- Username: `alice`
- Password: `#####` 

> ℹ️ Alice's password is stored in the secrets file. Follow the
> [decryption instructions](./setup.md#decrypt-the-secrets-file-plain-text)
> to access the plain-text content and retrieve the value of the
> `alice-password` key.

### Via SSH (LAN)

```sh
ssh alice@VM_IP
```

> ℹ️ You can discover the VM's internal IP from the host (without logging in
> directly) using a command like:\
> `sudo arp-scan --interface=br0 192.168.1.0/24`\

### Via SSH (Remotely)

The VM is configured to auto-connect to a Tailscale network.
See the [setup instructions](./setup.md#tailscale-auth-key) for details on key
validity, expiration, and renewal.

Once your local machine is connected to the same Tailnet, you can SSH into the
VM:

```sh
ssh alice@TAILSCALE_IP
```

> ℹ️ You can find the VM's Tailscale IP from the
> [Tailscale admin console](https://login.tailscale.com/admin/machines)
> or by running `tailscale status` on a connected machine.

## Update the VM

If you've made changes to [configuration.nix](../configuration.nix), you'll
need to rebuild the VM.

First, delete the existing VM image:

```sh
rm nixos.qcow2
```

Then, [**rebuild the VM**](#build-the-vm) to apply the updated configuration.

_Optional_: If you've connected to the VM via SSH before, remove its old host
key to avoid fingerprint conflicts:

```sh
ssh-keygen -R VM_IP -f ~/.ssh/known_hosts
```
