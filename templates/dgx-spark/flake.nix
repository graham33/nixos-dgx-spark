{
  description = "NixOS configuration for DGX Spark";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dgx-spark.url = "github:graham33/nixos-dgx-spark";
  };

  outputs = { self, nixpkgs, dgx-spark }:
    {
      nixosConfigurations.dgx-spark = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          dgx-spark.nixosModules.dgx-spark
        ];
      };
    };
}
