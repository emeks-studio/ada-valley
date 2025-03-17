# ada-valley
Cardano Ada Stake operator infra

## Pre-requisites

* Nix
* QEMU
* SOPS (sops-nix)

## Development
 
1. Setup your password

```bash
# Generate your age key!
nix-shell -p age --run "age-keygen -o ./secrets/$YOUR_USERNAME-password.key"
> Public key: age1fxrjjr86wcvypgkhgq63rz0uv04c6ss0glqyxh4w88a4gdfv5sys2s6vmk
# ^ Add your public in .sops.yaml

# Open the file and add the required keys:
# ex. alice-password: $(mkpasswd -m sha-512 $YOUR_SECRET_PASSWORD > ./secrets/alice-password.hash)
nix-shell -p sops --run "sops ./secrets/keys.enc.yaml"
```

1.a Decrypt using something like:
```bash
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=./secrets/$YOUR_USERNAME-password.key; sops -d ./secrets/keys.enc.yaml"
```

1.b If you add a new host to your .sops.yaml file, you will need to update the keys for all secrets that are used by the new host. This can be done like so:
```bash
nix-shell -p sops --run "sops updatekeys ./secrets/keys.enc.yaml"
```

2. Creating a QEMU based virtual machine from a NixOS configuration
    
```bash
# The old way:
# nix-build '<nixpkgs/nixos>' -A vm -I nixpkgs=channel:nixos-24.11 -I nixos-config=./configuration.nix

# with flakes:
nix build .#nixosConfigurations.nixos-vm.config.system.build.vm
```

3. Running the virtual machine

```bash
QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic; reset
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