{
  description = "NixOS VM configuration";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    iohkNix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cardano-node = {
      url = "github:intersectMBO/cardano-node";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, impermanence, haskellNix, iohkNix, cardano-node }: {
    nixosConfigurations = {
      nixos-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
            {  nixpkgs.overlays = [
                  # Crypto needs to come before haskell.nix. FIXME: _THIS_IS_BAD_
                  iohkNix.overlays.crypto
                  haskellNix.overlay
                  iohkNix.overlays.haskell-nix-extra
                  iohkNix.overlays.haskell-nix-crypto
                  iohkNix.overlays.cardano-lib
                  iohkNix.overlays.utils
                  cardano-node.overlay
                  (prev: final: {
                    cardano-cli = cardano-node.packages.${final.system}.cardano-cli;
                  })
              ];
            }
            ({ config, pkgs, ...}: {
                # Move fileSystems and virtualisation to a separate module!
                fileSystems."/usr/share/ada-valley" = {
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
  };
}