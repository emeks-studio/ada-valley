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

  outputs = { self, nixpkgs, sops-nix, impermanence, hackageNix, haskellNix, /* iohkNix,*/ cardano-node }: {
    nixosConfigurations = {
      nixos-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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