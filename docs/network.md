# Setup Network

Before starting the VM, check your network interfaces and identify the one
connected to the internet:

```sh
# Look for your main interface, e.g., enp3s0, eth0, etc
ip -br a
```

## Create TAP Interface and Network Bridge

QEMU's default networking isolates the VM. Bridging a TAP interface with the
physical interface gives the VM real LAN access, allowing it to obtain an IP
via DHCP and communicate as a separate device that is reachable from the
network.

**📝 vars**:
After creating the TAP interface (e.g., `tap0`), make sure to update
[vars.nix](../vars-template.nix) by setting the interface name under
`vm.tapInterface` for use by the VM.

### NixOS

Add the following to your NixOS configuration file
(`/etc/nixos/configuration.nix`), replacing `$NETWORK_INTERFACE` with your
host's physical network interface.\
_> Reference:_ https://nixos.wiki/wiki/Systemd-networkd

```nix
  networking.networkmanager.unmanaged = [ "$NETWORK_INTERFACE"];
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
   "46-$NETWORK_INTERFACE" = {
     matchConfig.Name = "$NETWORK_INTERFACE";
     networkConfig.Bridge = "br0";
   };
  };
```

### Other distros

Run the following commands:

```sh
# Set your actual network interface name
NETWORK_INTERFACE=enpXsY  # e.g., enp3s0, eth0, etc
# Load necessary kernel modules
sudo modprobe tun tap
# Create and bring up the bridge
sudo ip link add br0 type bridge
sudo ip link set dev br0 up
# Create tap device
sudo ip tuntap add dev tap0 mode tap
sudo ip link set tap0 master br0
sudo ip link set tap0 up
# Prepare and attach the physical interface
# ⚠️ This will temporarily disconnect your host from the network
sudo ip link set $NETWORK_INTERFACE down
sudo ip addr flush dev $NETWORK_INTERFACE
sudo ip link set $NETWORK_INTERFACE master br0
sudo ip link set $NETWORK_INTERFACE up
# Obtain IP address on the bridge
## DHCP (automatic)
sudo dhclient br0
## Static (example)
sudo ip addr add 192.168.1.100/24 dev br0 # Address
sudo ip route add default via 192.168.1.1 dev br0 # Gateway
```
