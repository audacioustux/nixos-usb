{
  description = "NixOS on USB — Root-on-tmpfs Impermanence Setup";

  inputs = {
    # Pin to the 25.11 stable branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs"; # avoid double nixpkgs in the closure
    };

    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, disko, impermanence }: {

    nixosConfigurations.usb = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # 1. Disko manages fileSystems.* for the USB partitions
        disko.nixosModules.disko

        # 2. Impermanence manages bind-mounts for persistent state
        impermanence.nixosModules.impermanence

        # 3. Your configs
        ./disko.nix
        ./configuration.nix
      ];
    };

  };
}
