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

## 1. Setup your password

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

^ Note: In case a new admin added their public key to the .sops.yaml file, you will need to run this command to update the keys file in order to authorize the new admin to decrypt the secrets.

1.b Only the first time, Open the file and add the required keys:
```bash
# ex. alice-password: $(mkpasswd -m sha-512 $YOUR_SECRET_PASSWORD > ./secrets/alice-password.hash)
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops ./secrets/keys.enc.yaml"
```

1.c  In case you need to decrypt the file:
```bash
nix-shell -p sops --run "export SOPS_AGE_KEY_FILE=/usr/share/ada-valley/age-password.key; sops -d ./secrets/keys.enc.yaml"
```

## 2. Network Setup

2. A) Create your network bridge (linux)

Look at your network interfaces and create a bridge for the VM
```bash
ip -br a # Look for something like "enpXs0"
```

```bash
sudo ip link add br0 type bridge
sudo ip link set dev br0 up
sudo ip link set $YOUR_NETWORK_INTERFACE master br0

modprobe tun tap
sudo ip tuntap add dev tap0 mode tap
sudo ip link set tap0 master br0
sudo ip link set tap0 up
```

2. B) Create you network bridge on nix

At your /etc/nixos/configuration.nix
```
  networking.networkmanager.unmanaged = [ "$YOUR_ETHERNET_NETWORK_INTERFACE"];
  systemd.network.enable = true;
  systemd.network.netdevs = {
    "42-br0" = {
      netdevConfig.Kind = "bridge";
      netdevConfig.Name = "br0";
    };
    "43-tap0" = {
      netdevConfig.Kind = "tap";
      netdevConfig.Name = "tap0";
    };
  };
  systemd.network.networks = {
    "44-br0" = {
      matchConfig.Name = "br0";
      networkConfig.DHCP = "yes";
    };
   "45-tap0" = {
     matchConfig.Name = "tap0";
     networkConfig.Bridge = "br0";
    };
   "46-$YOUR_ETHERNET_NETWORK_INTERFACE" = {
     matchConfig.Name = "$YOUR_ETHERNET_NETWORK_INTERFACE";
     networkConfig.Bridge = "br0";
   };
  };
```
^ Ref. https://nixos.wiki/wiki/Systemd-networkd

```bash
# Useful for monitoring the network
networkctl
ip -br a
```

## 3. Interacting with build package

The flake provides a help command to view the options available in the package

```nix
  nix run .#help
```

The full list of commands are:

### Build

 - `nix build .#nixosConfigurations.nixos-vm.config.system.build.vm --override-input varsFilePath path:./vars.nix`

### Execution

  - `nix run .#help` help command
  - `nix run .#show` To view how the vm will be started
  - `nix run .#start-vm` or simply `nix run .`



## 4. Cardano Node 
The Cardano node is configured in the configuration.nix as a systemd service called **cardano-node**, it will automatically starts on system startup, it will run the cardano node with these parameters:
 - topology: the one specified in the topology.json
 - database-path: will use the path defined in the vars.nix **vm.sharedFolder** variable
 - socket-path: will use the node.socket from the cardano-db stored into the **vm.sharedFOlder** variable
 - host-addr: will use the vm's interface defined as **eth1**
 - port: default 3001 can be parametrized
 - config: config.json 
  

### Check status:
```systemctl status cardano-node```

### Startup
```systemctl start cardano-node```

### View logs
```journalctl -fu cardano-node```

### Check progress
```
# Check sync progress
cardano-cli query tip --testnet-magic 2 --socket-path /usr/share/ada-valley/cardano-db/node.socket 
{
    "block": 11137,
    "epoch": 2,
    "era": "Alonzo",
    "hash": "924756fb4b3e974525966982b8cbbdd71c6b2bebd4c1e7e2c783647bcb7071de",
    "slot": 221974,
    "slotInEpoch": 49174,
    "slotsToEpochEnd": 37226,
    "syncProgress": "0.28"
}
```

5. A) Run inside/outside the VM

```bash
# Log-in by using alice credentials
[alice@nixos:~]$ sudo poweroff
```

5. B) Use ssh to enter the VM

```
# Make sure you are not connected to your wifi network. You need to be connected to the ethernet network.
ssh alice@VM_IP
```

## 6. Accessing Grafana

Access Grafana in your browser at http://VM_IP:4001

The default login credentials are:
- Username: `admin`  
- Password: `admin` (you'll be prompted to change this on first login)

Grafana comes preconfigured with a Prometheus data source that monitors:
- The Cardano node metrics (port 12798)
- System metrics via node_exporter (port 9100)

## Update the VM

1. Delete this file when you change the configuration

```bash 
rm nixos.qcow2

# In case you enter the VM using ssh, you will need to remove the ssh keys
ssh-keygen -R VM_IP -f /home/$YOUR_USER/.ssh/known_hosts
```

2. Run step 2 from Development section again!

## How do we initialize this project the 1st time?

```bash
nixos-generate-config --dir ./
```

Ref. https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html
