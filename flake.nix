{
  description = "NixOS USB disk image for aarch64-linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixos-generators, flake-utils }: let
    cuda13Overlay = final: prev: {
      cudaPackages = prev.cudaPackages_13;
    };
  in {
    # Expose the DGX Spark module for other projects
    nixosModules.dgx-spark = import ./modules/dgx-spark.nix;

    overlays.cuda-13 = cuda13Overlay;

    nixosConfigurations.usb-image = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        {
          # Enable cross-compilation if building from x86_64
          nixpkgs.crossSystem = {
            system = "aarch64-linux";
          };
        }
      ];
    };

    packages.aarch64-linux.usb-image = nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
      ];
      format = "iso";
    };

    packages.x86_64-linux.usb-image = nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.crossSystem = {
            system = "aarch64-linux";
          };
        }
      ];
      format = "iso";
    };

    # Default package
    packages.aarch64-linux.default = self.packages.aarch64-linux.usb-image;
    packages.x86_64-linux.default = self.packages.x86_64-linux.usb-image;

  } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
        overlays = [
          cuda13Overlay
        ];
      };
    in {
      # Dev shells
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          cudaPackages.cuda_nvcc
        ];
      };
  });
}
