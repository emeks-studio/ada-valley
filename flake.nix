{
  nixConfig = {
    # This sets the flake to use the IOG nix cache (and others).
    # Nix should ask for permission before using it,
    # but remove it here if you do not want it to.
    extra-substituters = [
      "https://cache.iog.io"
      "https://pre-commit-hooks.cachix.org"
      "https://emeks-public.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
      "emeks-public.cachix.org-1:sz2oZuYq7EsRb5FW6sDtpPU1CWh+6ymOgxFgmrYTKGI="
    ];
  };

  description = "NixOS VM configuration";

  # UPGRADE INSTRUCTIONS:
  # Ref. https://github.com/disassembler/network
  # ^ I Usually search in the flake.nix of this repo in order to know which versions to use.
  #   After changing the versions in our flake.nix run `nix flake update` to update the lock file.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";

    varsFilePath = {
      # Default to vars-template.nix please make your own vars.nix and override the input!
      url = "path:./vars-template.nix"; 
      flake = false;
    };

    cardano-node = {
      url = "github:intersectmbo/cardano-node/10.5.1";
    };

    ssh-keys = {
      url = "path:./ssh-keys";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-generators, sops-nix, impermanence, cardano-node, varsFilePath, ssh-keys }:
    let 
      vars = builtins.import varsFilePath;
      system = "x86_64-linux";
      vm_runner = "./result/bin/run-nixos-vm";
      pkgs = nixpkgs.legacyPackages.${system};
      configurationPorts = [22 80 9090 9100 12798 4001];
      configEnv = {
        PORTS = builtins.concatStringsSep " " (map toString configurationPorts);
      };
      nodeOverlays = [
        (prev: final: {
          cardano-cli = cardano-node.packages.${final.system}.cardano-cli;
          cardano-node = cardano-node.packages.${final.system}.cardano-node;
        })
        (import ./overlays/cardano-configs-testnet-preview.nix)
        (import ./overlays/cardano-configs-testnet-preprod.nix)
        (import ./overlays/cardano-configs-mainnet.nix)
        (import ./overlays/grafana-dashboards.nix)
        (import ./overlays/cardano-auditor.nix { inherit configEnv; })
      ];
    in {

    # In the bootable after copy files (flake.nix and configuration-iso.nix) to /mnt/etc/nixos/
    # sudo nixos-install --flake /mnt/etc/nixos/#bichota
    nixosConfigurations = {
      # This configuration can be used for installation with:
      # sudo nixos-install --flake /mnt/etc/nixos/#bichota
      bichota = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit vars configurationPorts;
        };
        modules = [
          { nixpkgs.overlays = nodeOverlays; }
          ({ config, pkgs, ...}: {
              environment.etc = builtins.listToAttrs (
                map 
                  (fileName: {
                    name = "ssh/authorized_keys.d/${fileName}";
                    value = {
                      source = "${ssh-keys}/${fileName}";
                      mode = "0444";
                    };
                  })
                  (builtins.attrNames (builtins.readDir ssh-keys))
              );
          })
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          ./configuration-iso-wifi.nix
          /etc/nixos/hardware-configuration.nix
          {
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
          }
        ];
      };
    };

    packages.${system} = {

      # Note: In order to use this with VirtualBox you need to disable:
      # sudo modprobe -r kvm_intel 
      # ^ For Intel CPUs or kvm_amd for AMD CPUs
      # And in case you want to re-enable it:
      # sudo modprobe kvm_intel
      bichota-iso = nixos-generators.nixosGenerate {
        system = "${system}";
        format = "iso";
        specialArgs = {
          inherit vars configurationPorts;
        };
        modules = [
          {  nixpkgs.overlays = nodeOverlays; }
          ({ config, pkgs, ...}: {
              environment.etc = builtins.listToAttrs (
                map 
                  (fileName: {
                    name = "ssh/authorized_keys.d/${fileName}";
                    value = {
                      source = "${ssh-keys}/${fileName}";
                      mode = "0444";
                    };
                  })
                  (builtins.attrNames (builtins.readDir ssh-keys))
              );
          })
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          # Apply the rest of the config.
          ./configuration-iso.nix
        ];
      };

      bichota-iso-wifi = nixos-generators.nixosGenerate {
        system = "${system}";
        format = "iso";
        specialArgs = {
          inherit vars configurationPorts;
        };
        modules = [
          {  nixpkgs.overlays = nodeOverlays; }
          ({ config, pkgs, ...}: {
              environment.etc = builtins.listToAttrs (
                map 
                  (fileName: {
                    name = "ssh/authorized_keys.d/${fileName}";
                    value = {
                      source = "${ssh-keys}/${fileName}";
                      mode = "0444";
                    };
                  })
                  (builtins.attrNames (builtins.readDir ssh-keys))
              );
          })
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          # Apply the WiFi-enabled config
          ./configuration-iso-wifi.nix
        ];
      };

      bichota-qemu-vm = nixos-generators.nixosGenerate {
        system = "${system}";
        format = "vm"; # only used as a qemu-kvm runner
        specialArgs = {
          inherit vars configurationPorts;
        };
        modules = [
          {  nixpkgs.overlays = nodeOverlays; }
          ({ config, pkgs, ...}: {
              # Move fileSystems and virtualisation to a separate module!
              fileSystems."${vars.vm.sharedFolder}" = {
                device = "hostshared";
                neededForBoot = true;
                fsType = "9p";
                options = [ "trans=virtio" "version=9p2000.L" "cache=mmap" ];
              };
              environment.etc = builtins.listToAttrs (
                map 
                  (fileName: {
                    name = "ssh/authorized_keys.d/${fileName}";
                    value = {
                      source = "${ssh-keys}/${fileName}";
                      mode = "0444";
                    };
                  })
                  (builtins.attrNames (builtins.readDir ssh-keys))
              );
          })
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          # Apply the rest of the config.
          ./configuration-vm.nix
        ];
      };

      start-vm = pkgs.writeShellApplication {
        name = "start-vm";
        runtimeInputs = [pkgs.qemu_kvm];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          VM_RUNNER="${vm_runner}"

          if [ ! -x "$VM_RUNNER" ] ; then
            echo "Error VM not found"
            echo "Try to generate it with: nix build .#bichota-qemu-vm"
            exit 1
          fi

          QEMU_KERNEL_PARAMS=console=ttyS0 \
          "$VM_RUNNER" \
            -nographic \
            -fsdev local,id=fsdev0,path=${vars.vm.sharedFolder},security_model=none \
            -device virtio-9p-pci,fsdev=fsdev0,mount_tag=hostshared \
            -netdev tap,id=net0,ifname=${vars.vm.tapInterface},script=no,downscript=no \
            -device virtio-net-pci,netdev=net0 -m ${vars.vm.vmMemory}
        '';
      };
      help = pkgs.writeShellApplication {
        name = "help";
        text = ''
          echo
          echo "Available commands:"
          echo "  nix build .#bichota-iso --override-input varsFilePath path:./vars.nix         - Build the NixOS .iso (wired network)"
          echo "  nix build .#bichota-iso-wifi --override-input varsFilePath path:./vars.nix    - Build the NixOS .iso (WiFi enabled)"
          echo "  nix build .#bichota-qemu-vm --override-input varsFilePath path:./vars.nix     - Build the NixOS QEMU VM RUNNER"
          echo "  nix develop .#keys                                                            - Enter shell to build alice-keys disk"
          echo "  nix run .#start-vm                                                            - Run the NixOS VM with QEMU"
          echo "  nix run .#help                                                                - Show this help message"
          echo "  nix run .#show                                                                - Show vm startup command"
          echo "  sudo nix run github:emeks-studio/ada-valley[/branch]#install -- /dev/sdX      - Clone that exact branch/rev + install NixOS to disk (run from live ISO)"
        '';
      };
      show = pkgs.writeShellApplication {
        name = "show";
        text = ''
          echo
          echo "Starting VM with the following variables"
          echo "
            QEMU_KERNEL_PARAMS=console=ttyS0 \
            ${vm_runner} \
            -nographic \
            -fsdev local,id=fsdev0,path=${vars.vm.sharedFolder},security_model=none \
            -device virtio-9p-pci,fsdev=fsdev0,mount_tag=hostshared \
            -netdev tap,id=net0,ifname=${vars.vm.tapInterface},script=no,downscript=no \
            -device virtio-net-pci,netdev=net0 -m ${vars.vm.vmMemory}
          "
        '';
      };

      # NOTE: This script re-clones the repo into /mnt/etc/nixos even though
      # Nix already had to fetch the flake to run `nix run .#install` itself.
      # That's intentional: the flake source Nix used could be an immutable/
      # read-only store path, but nixos-install needs a real, mutable git
      # checkout living at /mnt/etc/nixos (which also becomes /etc/nixos on
      # the installed system, ready for future `nixos-rebuild switch`).
      #
      # IMPORTANT: To install from a specific branch, put the branch in the
      # flake reference itself (this is what actually gets evaluated/run):
      #   nix run github:emeks-studio/ada-valley/feat/iso-wifi#install -- /dev/sda
      # The script below then clones that SAME revision (self.rev/self.shortRev
      # when available) so the installed system matches exactly what you ran.
      install = pkgs.writeShellApplication {
        name = "install";
        runtimeInputs = [pkgs.git pkgs.nixos-install-tools pkgs.util-linux];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Usage: nix run github:emeks-studio/ada-valley[/branch]#install -- <target-disk>
          # Example: nix run github:emeks-studio/ada-valley/feat/iso-wifi#install -- /dev/sda
          # (!) WARNING (!) This will install NixOS to the target disk using
          # nixosConfigurations.bichota (see flake.nix). It expects to be run
          # from a live NixOS ISO booted with this flake.
          # It clones the exact revision this flake was invoked from, so the
          # branch/commit is determined by the flake ref you used above -
          # NOT by a script argument (avoids the two sources of truth problem).

          REPO_URL="git@github.com:emeks-studio/ada-valley.git"
          # self.rev only exists for clean, committed (non-dirty) flake refs
          # (e.g. github:owner/repo/branch). Falls back to "main" for local
          # `nix run .#install` dev usage where self.rev is unavailable.
          REV="${self.rev or "main"}"

          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 <target-disk>"
            echo "  <target-disk>  e.g. /dev/sda (informational only, disk must already be partitioned)"
            echo "This assumes the target disk is ALREADY partitioned and mounted at /mnt"
            echo "(boot partition at /mnt/boot, if applicable)."
            echo
            echo "To install from a specific branch, re-run this command as:"
            echo "  nix run github:emeks-studio/ada-valley/<branch>#install -- <target-disk>"
            exit 1
          fi

          TARGET_DISK="$1"

          if ! mountpoint -q /mnt; then
            echo "Error: /mnt is not mounted. Partition and mount your target disk first."
            exit 1
          fi

          echo "==> Target disk: $TARGET_DISK"
          echo "==> Cloning $REPO_URL @ $REV into /mnt/etc/nixos ..."
          rm -rf /mnt/etc/nixos
          mkdir -p /mnt/etc/nixos
          git clone --depth 1 --branch "$REV" "$REPO_URL" /mnt/etc/nixos \
            || git clone "$REPO_URL" /mnt/etc/nixos && git -C /mnt/etc/nixos checkout "$REV"

          echo "==> Generating hardware-configuration.nix ..."
          nixos-generate-config --root /mnt

          # (!) By default the flake uses vars-template.nix (see varsFilePath input).
          # If you have your own vars.nix, place it at /mnt/etc/nixos/vars.nix
          # BEFORE running this script, and it will be used instead via --override-input.
          INSTALL_FLAGS=()
          if [ -f /mnt/etc/nixos/vars.nix ]; then
            echo "==> Found custom vars.nix, overriding varsFilePath input"
            INSTALL_FLAGS+=(--override-input varsFilePath "path:/mnt/etc/nixos/vars.nix")
          else
            echo "WARNING: No /mnt/etc/nixos/vars.nix found."
            echo "WARNING: Falling back to vars-template.nix defaults (nodeConfig=mainnet)."
          fi

          echo "==> Installing NixOS using flake #bichota ..."
          nixos-install --flake /mnt/etc/nixos#bichota "''${INSTALL_FLAGS[@]}"

          echo "==> Installation complete! You can now reboot into your new system."
        '';
      };
    };

    apps.${system} = {
      default = {
          type = "app";
          program = "${self.packages.${system}.start-vm}/bin/start-vm";
      };
      help = {
        type = "app";
        program = "${self.packages.${system}.help}/bin/help";
      };
      show = {
        type = "app";
        program = "${self.packages.${system}.show}/bin/show";
      };
      install = {
        type = "app";
        program = "${self.packages.${system}.install}/bin/install";
      };
    };
  };
}