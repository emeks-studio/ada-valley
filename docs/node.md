# Cardano Node

The Cardano node is defined in [configuration.nix](../configuration.nix) as a
systemd service named **cardano-node**.\
It starts automatically on system boot and runs with the following parameters:

- **topology**\
  Specified in [topology.json](../cardano-configs-testnet-preview/topology.json)
- **database-path**\
  Set to the directory defined by the `vm.sharedFolder` variable in
  [vars.nix](../vars-template.nix)
- **socket-path**\
  Points to `node.socket` inside the cardano-db stored in `vm.sharedFolder`
- **host-addr**\
  Bound to the VM interface `eth1`
- **port**\
  Defaults to `3001` but can be customized
- **config**\
  Uses [config.json](../cardano-configs-testnet-preview/config.json)

## Service Management

> ℹ️ All commands for managing the **cardano-node** service must be run inside
> the VM.

### Check service status

```sh
systemctl status cardano-node
```

### Start the service

```sh
sudo systemctl start cardano-node
```

### View logs

```sh
journalctl -fu cardano-node
```

### Check sync progress

```sh
# for mainnet
cardano-cli query tip --mainnet --socket-path /usr/share/ada-valley/cardano-db/node.socket

# Or for testnet-preview
cardano-cli query tip --testnet-magic 2 --socket-path /usr/share/ada-valley/cardano-db/node.socket
# Example output:
# {
#   "block": 11137,
#   "epoch": 2,
#   "era": "Alonzo",
#   "hash": "924756fb4b3e974525966982b8cbbdd71c6b2bebd4c1e7e2c783647bcb7071de",
#   "slot": 221974,
#   "slotInEpoch": 49174,
#   "slotsToEpochEnd": 37226,
#   "syncProgress": "0.28"
# }
```

## Accessing Grafana

To view the Grafana dashboard, open your browser and navigate to
`http://VM_IP:4001`.

Default login credentials:

- Username: `admin`
- Password: `admin` (you will be prompted to change it on first login)

Grafana is preconfigured with a Prometheus data source that monitors:

- Cardano node metrics (port 12798)
- System metrics via node_exporter (port 9100)
