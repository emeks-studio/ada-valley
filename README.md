# ada-valley
Cardano Ada Stake operator infra

## Pre-requisites

* Nix
* QEMU
* SOPS (sops-nix)
* Impermanence (nix-community/impermanence)

## Development

0. Setup shared folder

```
sudo mkdir -p /usr/share/ada-valley
sudo chmod -R 777 /usr/share/ada-valley
```

1. Setup your password

```bash
# Generate your age key!
nix-shell -p age --run "age-keygen -o /usr/share/ada-valley/age-password.key"
> Public key: age1fxrjjr86wcvypgkhgq63rz0uv04c6ss0glqyxh4w88a4gdfv5sys2s6vmk
# ^ Append your public in .sops.yaml like this:
# - &admin_$your_name age1fxrjjr86wcvypgkhgq63rz0uv04c6ss0glqyxh4w88a4gdfv5sys2s6vmk
```

1.a Encrypting the keys file

If you add a new host to your .sops.yaml file, you will need to update the keys for all secrets that are used by the new host. This can be done like so:

```bash
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops updatekeys ./secrets/keys.enc.yaml"
```

1.b Only the first time, Open the file and add the required keys:
```bash
# ex. alice-password: $(mkpasswd -m sha-512 $YOUR_SECRET_PASSWORD > ./secrets/alice-password.hash)
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops ./secrets/keys.enc.yaml"
```

1.c  In case you need to decrypt the file:
```bash
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops -d ./secrets/keys.enc.yaml"
```

2. A) Create your network bridge (linux)

Look at your network interfaces and create a bridge for the VM
```bash
ip -br a # Look for something like "enpXs0"
```

```bash
sudo ip link add br0 type bridge
sudo ip link set dev br0 up
sudo ip link set $YOUR_NETWORK_INTERFACE master br0
```

Lastly, modify /etc/qemu/bridge.conf
```
allow br0
```

2. B) Create you network bridge on nix

At your /etc/nixos/configuration.nix
```
networking.interfaces.enp7s0.useDHCP = false;
networking.bridges.br0.interfaces = ["enp7s0"]; # Use your interface!
  networking.interfaces.br0 = {
    useDHCP = true;
  };
```

```bash
systemctl start br0-netdev.service
```

Lastly, modify /etc/qemu/bridge.conf
```
allow br0
```

3. Creating a QEMU based virtual machine from a NixOS configuration
    
```bash
# The old way:
# nix-build '<nixpkgs/nixos>' -A vm -I nixpkgs=channel:nixos-24.11 -I nixos-config=./configuration.nix

# with flakes:
nix build .#nixosConfigurations.nixos-vm.config.system.build.vm
```

4. Running the virtual machine

```bash
QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic -fsdev local,id=fsdev0,path=/usr/share/ada-valley,security_model=none -device virtio-9p-pci,fsdev=fsdev0,mount_tag=hostshared -netdev bridge,br=br0,id=net0 -device virtio-net-pci,netdev=net0; reset
```

5. Run outside the VM

```bash
[alice@nixos:~]$ sudo poweroff
```

## Update the VM

1. Delete this file when you change the configuration

```bash 
rm nixos.qcow2
```

2. Run step 2 from Development section again!

## How do we initialize this project the 1st time?

```bash
nixos-generate-config --dir ./
```

Ref. https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html