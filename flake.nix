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
                fileSystems."/usr/shared/ada-valley" = {
                  device = "hostshared";
                  fsType = "9p";
                  options = [ "trans=virtio" "version=9p2000.L" "cache=mmap" ];
                };
                # TODO: Add flags to the QEMU CMD
                # virtualisation.qemu-vm.options = [
                #   "-fsdev local,id=fsdev0,path=/usr/shared/ada-valley,security_model=none" "-device virtio-9p-pci,fsdev=fsdev0,mount_tag=hostshared"
                # ];
            })
            sops-nix.nixosModules.sops
            impermanence.nixosModules.impermanence
            ./configuration.nix 
        ];
      };
    };
  };
}