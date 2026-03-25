# ada-valley
Cardano ADA Stake operator infra.

## Pre-requisites

- [Nix](https://nixos.org/learn/)
- [QEMU](https://www.qemu.org/documentation/)
- [SOPS](https://getsops.io/docs/) (sops-nix)
- [Impermanence](https://github.com/nix-community/impermanence) (nix-community/impermanence)

> ℹ️ This setup was originally bootstrapped with
> [nixos-generate-config --dir ./](https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html)

## Documentation

1. [Shared Folder & SSH Key](docs/setup.md)
2. [Secrets Management](docs/setup.md#secrets)
3. [External Keys Setup (ISO/USB)](docs/external-keys-setup.md)
4. [Network Setup](docs/network.md)
5. [Package Commands & Build](docs/package.md)
6. [Cardano Node Usage](docs/node.md)
