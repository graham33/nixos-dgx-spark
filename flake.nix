{
  description = "NixOS USB disk image for aarch64-linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, flake-utils, pre-commit-hooks }:
    let
      cuda13Overlay = import ./overlays/cuda-13.nix;
    in
    {
      # Expose the DGX Spark module for other projects
      nixosModules.dgx-spark = import ./modules/dgx-spark.nix;

      overlays.cuda-13 = cuda13Overlay;
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

        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            markdownlint.enable = true;
            trailing-whitespace = {
              enable = true;
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/trailing-whitespace-fixer";
            };
            end-of-file-fixer = {
              enable = true;
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/end-of-file-fixer";
            };
          };
        };
      in
      {
        # Dev shells
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cudaPackages.cuda_cuobjdump
            cudaPackages.cuda_nvcc
            cudaPackages.cuda-samples
            # llama-cpp
            pythonEnv
            pre-commit
            nixpkgs-fmt
            markdownlint-cli
          ];

          # Add NVIDIA driver libraries to the environment
          shellHook = ''
            echo "CUDA samples available at: ${pkgs.cudaPackages.cuda-samples}/bin"
            ${pre-commit-check.shellHook}
          '';
        };

        devShells.llama-cpp = pkgs.mkShell {
          packages = with pkgs; [
            llama-cpp
          ];
        };

        packages.cuda-debug = pkgs.callPackage ./packages/cuda-debug { };

        packages.usb-image = nixos-generators.nixosGenerate {
          system = "aarch64-linux";
          modules = [
            ./configuration.nix
          ] ++ nixpkgs.lib.optional (system == "x86_64-linux") {
            nixpkgs.crossSystem = {
              system = "aarch64-linux";
            };
          };
          format = "iso";
        };

        packages.default = self.packages.${system}.usb-image;

        checks.pre-commit-check = pre-commit-check;

        apps.pytorch-container = {
          type = "app";
          program = "${pkgs.writeShellScript "pytorch-container" ''
          exec ${pkgs.podman}/bin/podman run --rm -it --signature-policy=$PWD/policy.json --device nvidia.com/gpu=all nvcr.io/nvidia/pytorch:25.09-py3 /bin/bash
        ''}";
        };
      });
}
