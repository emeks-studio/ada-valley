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

  outputs = { self, nixpkgs, sops-nix, impermanence, cardano-node, varsFilePath, ssh-keys }:
    let 
      vars = builtins.import varsFilePath;
      system = "x86_64-linux";
      vm_runner = "./result/bin/run-nixos-vm";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    nixosConfigurations = {
      nixos-vm = nixpkgs.lib.nixosSystem {
        system = "${system}";
        specialArgs = { inherit vars; };
        modules = [ 
            {  nixpkgs.overlays = [
                  (prev: final: {
                    cardano-cli = cardano-node.packages.${final.system}.cardano-cli;
                    cardano-node = cardano-node.packages.${final.system}.cardano-node;
                  })
                  (import ./overlays/cardano-configs-testnet-preview.nix)
                  (import ./overlays/grafana-dashboards.nix)
                  (import ./overlays/cardano-auditor.nix)
              ];
            }
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
            ./configuration.nix 
        ];
      };
    };

    packages.${system} = {
      start-vm = pkgs.writeShellApplication {
        name = "start-vm";
        runtimeInputs = [pkgs.qemu_kvm];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          VM_RUNNER="${vm_runner}"

          if [ ! -x "$VM_RUNNER" ] ; then
            echo "Error VM not found"
            echo "Try to generate it with: nix build .#nixosConfigurations.vm.config.system.build.vm"
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
          echo "  nix build .#nixosConfigurations.nixos-vm.config.system.build.vm --override-input varsFilePath path:./vars.nix     - Build the NixOS VM"
          echo "  nix run .#start-vm                                                                                                - Run the VM with QEMU"
          echo "  nix run .#help                                                                                                    - Show this help message"
          echo "  nix run .#show                                                                                                    - Show vm startup command"
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
    };
  };
}