{
  description = "NixOS USB disk image for aarch64-linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixified-ai = {
      url = "github:nixified-ai/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, flake-utils, pre-commit-hooks, nixified-ai }:
    let
      cudaSbsaOverlay = import ./overlays/cuda-sbsa.nix;
      cuda129Overlay = import ./overlays/cuda-12.9.nix;
      cutlass43Overlay = import ./overlays/cutlass-4.3.nix;
      pytorchCutlass43Overlay = import ./overlays/pytorch-cutlass-4.3.nix;
      cuda13Overlay = import ./overlays/cuda-13.nix;
      korniaRsOverlay = import ./overlays/kornia-rs.nix;
      comfyuiModelsOverlay = import ./overlays/comfyui-models.nix;
    in
    {
      # Expose the DGX Spark module for other projects
      nixosModules.dgx-spark = import ./modules/dgx-spark.nix;

      overlays.cuda-13 = cuda13Overlay;

      templates.dgx-spark = {
        path = ./templates/dgx-spark;
        description = "NixOS configuration template for DGX Spark systems";
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        commonConfig = {
          allowUnfree = true;
          allowUnsupportedSystem = true;
          cudaSupport = true;
          # Use architecture-specific features
          # https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/compute-capabilities.html#architecture-specific-features
          cudaCapabilities = [ "12.1a" ];
        };

        pkgs = import nixpkgs {
          inherit system;
          config = commonConfig;
          overlays = [
            cudaSbsaOverlay
            cuda13Overlay
          ];
        };

        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          torch
        ]);

        # Separate pkgs for ComfyUI using CUDA 12 (opencv not compatible with CUDA 13)
        pkgsCuda12 = import nixpkgs {
          inherit system;
          config = commonConfig;
          overlays = [
            cudaSbsaOverlay
            cuda129Overlay
            cutlass43Overlay
            pytorchCutlass43Overlay
            korniaRsOverlay
            nixified-ai.overlays.comfyui
            nixified-ai.overlays.models
            nixified-ai.overlays.fetchers
            comfyuiModelsOverlay
          ];
        };

        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt = {
              enable = true;
              excludes = [ "^kernel-configs/" ];
            };
            prettier = {
              enable = true;
              types_or = [ "markdown" ];
            };
            trailing-whitespace = {
              enable = true;
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/trailing-whitespace-fixer";
              excludes = [
                "^patches/"
                "^vendor/"
              ];
            };
            end-of-file-fixer = {
              enable = true;
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/end-of-file-fixer";
              excludes = [
                "^patches/"
                "^vendor/"
              ];
            };
          };
        };
      in
      {
        # Dev shells
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pre-commit
            nixpkgs-fmt
            nodePackages.prettier
          ];

          shellHook = ''
            ${pre-commit-check.shellHook}
          '';
        };

        devShells.cuda = pkgs.mkShell {
          packages = with pkgs; [
            cudaPackages.cuda_cuobjdump
            cudaPackages.cuda_nvcc
            cudaPackages.cuda-samples
            pythonEnv
          ];

          # Add NVIDIA driver libraries to the environment
          shellHook = ''
            echo "CUDA samples available at: ${pkgs.cudaPackages.cuda-samples}/bin"
            ${pre-commit-check.shellHook}
          '';
        };

        devShells.torch = pkgs.mkShell {
          packages = with pkgs; [
            pythonEnv
          ];
        };

        devShells.llama-cpp = pkgs.mkShell {
          packages = with pkgs; [
            llama-cpp
          ];
        };

        devShells.comfyui = pkgsCuda12.mkShell {
          packages = [
            (pkgsCuda12.comfyuiPackages.comfyui.override {
              withModels = [ pkgsCuda12.comfyuiModels.sd15-fp16 ];
            })
          ];
        };

        devShells.vllm-container = import ./playbooks/vllm-container/shell.nix { inherit pkgs; };

        packages.cuda-debug = pkgs.callPackage ./packages/cuda-debug { };

        # USB image with NVIDIA kernel (default) and standard kernel specialisation
        packages.usb-image = nixos-generators.nixosGenerate {
          system = "aarch64-linux";
          modules = [
            ./usb-configuration.nix
          ] ++ nixpkgs.lib.optional (system == "x86_64-linux") {
            nixpkgs.crossSystem = {
              system = "aarch64-linux";
            };
          };
          format = "iso";
        };

        packages.default = self.packages.${system}.usb-image;

        # Expose pkgsCuda12 for downstream flakes to access ComfyUI packages, models, and fetchers
        legacyPackages = {
          inherit pkgsCuda12;
        };

        checks.pre-commit-check = pre-commit-check;

        apps.pytorch-container = {
          type = "app";
          program = "${pkgs.writeShellScript "pytorch-container" ''
          exec ${pkgs.podman}/bin/podman run --rm -it --signature-policy=$PWD/policy.json --device nvidia.com/gpu=all nvcr.io/nvidia/pytorch:25.09-py3 /bin/bash
        ''}";
        };
      });
}
