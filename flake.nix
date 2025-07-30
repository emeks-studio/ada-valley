{
  description = "NixOS VM configuration";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";
    hackageNix = {
      url = "github:input-output-hk/hackage.nix?ref=for-stackage";
      flake = false;
    };

    varsFilePath = {
      # Default to vars-template.nix please make your own vars.nix and override the input!
      url = "path:./vars-template.nix"; 
      flake = false;
    };

    haskellNix = {
      # GHC 8.10.7 cross compilation for windows is broken in newer versions of haskell.nix.
      # Unpin this once we no longer need GHC 8.10.7.
      url = "github:input-output-hk/haskell.nix/cb139fa956158397aa398186bb32dd26f7318784";
      inputs.hackage.follows = "hackageNix";
      # url = "github:input-output-hk/haskell.nix/14f740c7c8f535581c30b1697018e389680e24cb";
      # ^ error: The option `flake' does not exist. Definition values:
      #  - In `<unknown-file>':
      #      {
      #        variants = {
      #          ghc96 = {
      #            compiler-nix-name = "ghc96";
      #          };
    };

    #iohkNix = {
    #  url = "github:input-output-hk/iohk-nix";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    # Ref. https://github.com/disassembler/network
    cardano-node = {
      url = "github:intersectmbo/cardano-node/10.1.4";
      inputs.haskellNix.follows = "haskellNix";
    };
  };

  outputs = { self, nixpkgs, sops-nix, impermanence, hackageNix, haskellNix, /* iohkNix,*/ cardano-node, varsFilePath }:
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
                  # Crypto needs to come before haskell.nix. FIXME: _THIS_IS_BAD_
                  # iohkNix.overlays.crypto
                  # haskellNix.overlay
                  # iohkNix.overlays.haskell-nix-extra
                  # iohkNix.overlays.haskell-nix-crypto
                  # iohkNix.overlays.cardano-lib
                  # iohkNix.overlays.utils
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