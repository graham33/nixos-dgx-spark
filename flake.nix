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

      magma = prev.magma.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          (final.fetchpatch {
            name = "magma-fix-cuda-version-detection.patch";
            url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
            hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU="; # Replace with actual hash
          })
        ];
      });
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
          cudaCapabilities = [ "12.0" "12.1" ];
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

      packages.pkgs-for-debugging = pkgs;
      packages.torch = pkgs.python3Packages.torch;

      packages.cuda-debug = pkgs.stdenv.mkDerivation rec {
        pname = "cuda-debug";
        version = "1.0";
        src = ./.;
        buildInputs = [ pkgs.cudaPackages.cuda_cudart ];
        nativeBuildInputs = [ pkgs.cudaPackages.cuda_nvcc pkgs.autoAddDriverRunpath ];

        inherit (pkgs.cudaPackages.flags) cudaCapabilities;

        buildPhase = let
          gencode = pkgs.lib.concatMapStringsSep " " (cap:
            "--generate-code arch=compute_${pkgs.lib.replaceStrings ["."] [""] cap},code=sm_${pkgs.lib.replaceStrings ["."] [""] cap}"
          ) cudaCapabilities;
        in ''
          nvcc ${gencode} -o cuda-debug cuda-debug.cu -L${pkgs.cudaPackages.cuda_cudart}/lib/stubs -lcuda -lcudart
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp cuda-debug $out/bin/
        '';
      };
  });
}
