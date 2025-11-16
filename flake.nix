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
    cuda13Overlay = import ./overlays/cuda-13.nix;
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
          cudaCapabilities = [ "12.0" ]; # TODO: try 12.1
        };
        overlays = [
          cuda13Overlay
        ];
      };

      pythonEnv = pkgs.python3.withPackages (ps: with ps; [
        torch
      ]);
    in {
      # Dev shells
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          cudaPackages.cuda_cuobjdump
          cudaPackages.cuda_nvcc
          cudaPackages.cuda-samples
          # llama-cpp
          pythonEnv
        ];

        # Add NVIDIA driver libraries to the environment
        shellHook = ''
          echo "CUDA samples available at: ${pkgs.cudaPackages.cuda-samples}/bin"
        '';
      };

      devShells.llama-cpp = pkgs.mkShell {
        packages = with pkgs; [
          llama-cpp
        ];
      };

      packages.pkgs = pkgs;  # for debugging

      packages.cuda-debug = pkgs.callPackage ./packages/cuda-debug { };

      apps.pytorch-container = {
        type = "app";
        program = "${pkgs.writeShellScript "pytorch-container" ''
          exec ${pkgs.podman}/bin/podman run --rm -it --signature-policy=$PWD/policy.json --device nvidia.com/gpu=all nvcr.io/nvidia/pytorch:25.09-py3 /bin/bash
        ''}";
      };
  });
}
