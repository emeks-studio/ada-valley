{
  description = "NixOS VM configuration";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, sops-nix, impermanence }: {
    nixosConfigurations = {
      nixos-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
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