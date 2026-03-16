{
  description = "NixOS USB disk image for aarch64-linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-gl-host = {
      url = "github:numtide/nix-gl-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixified-ai = {
      url = "github:nixified-ai/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , nix-gl-host
    , pre-commit-hooks
    , nixified-ai
    ,
    }:
    let
      linux617Overlay = import ./overlays/linux-6.17.nix;
      cudaSbsaOverlay = import ./overlays/cuda-sbsa.nix;
      cuda13Overlay = import ./overlays/cuda-13.nix;
      korniaRsOverlay = import ./overlays/kornia-rs.nix;
      comfyuiModelsOverlay = import ./overlays/comfyui-models.nix;
      dlpackOverlay = import ./overlays/dlpack.nix;
      vllmDepsOverlay = import ./overlays/vllm-deps.nix;
    in
    {
      # Expose the DGX Spark module for other projects
      nixosModules.dgx-spark = import ./modules/dgx-spark.nix;
      nixosModules.dgx-dashboard = import ./modules/dgx-dashboard.nix;

      overlays.cuda-13 = cuda13Overlay;

      templates.dgx-spark = {
        path = ./templates/dgx-spark;
        description = "NixOS configuration template for DGX Spark systems";
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        commonConfig = {
          allowUnfree = true;
          allowUnsupportedSystem = true;
          cudaSupport = true;
          cudaCapabilities = [ "12.0" ]; # TODO: try 12.1
        };

        pkgs = import nixpkgs {
          inherit system;
          config = commonConfig;
          overlays = [
            linux617Overlay
            cudaSbsaOverlay
            cuda13Overlay
            dlpackOverlay
            vllmDepsOverlay
            korniaRsOverlay
            nixified-ai.overlays.comfyui
            nixified-ai.overlays.models
            nixified-ai.overlays.fetchers
            comfyuiModelsOverlay
          ];
        };

        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            torch
          ]
        );

        pythonForKernelConfig = pkgs.python3.withPackages (ps: [ ps.pytest ]);

        nixglhost = nix-gl-host.packages.${system}.default;

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
            nixglhost
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
            nixglhost
            cudaPackages.cuda_cuobjdump
            cudaPackages.cuda_nvcc
            cudaPackages.cuda-samples
          ];

          # Add NVIDIA driver libraries to the environment
          shellHook = ''
            echo "CUDA samples available at: ${pkgs.cudaPackages.cuda-samples}/bin"
            ${pre-commit-check.shellHook}
          '';
        };

        devShells.torch = pkgs.mkShell {
          packages = with pkgs; [
            nixglhost
            pythonEnv
          ];
        };

        devShells.llama-cpp = pkgs.mkShell {
          packages = with pkgs; [
            nixglhost
            llama-cpp
          ];
        };

        devShells.comfyui = pkgs.callPackage ./playbooks/comfyui/shell.nix { inherit nixglhost; };
        devShells.flux-dreambooth = pkgs.callPackage ./playbooks/flux-dreambooth/shell.nix { inherit nixglhost; };
        devShells.multimodal-inference = pkgs.callPackage ./playbooks/multimodal-inference/shell.nix { inherit nixglhost; };
        devShells.pytorch-finetune = pkgs.callPackage ./playbooks/pytorch-finetune/shell.nix { inherit nixglhost; };
        devShells.pytorch-finetune-nix = pkgs.callPackage ./playbooks/pytorch-finetune-nix/shell.nix { inherit nixglhost; };

        devShells.vllm-container = pkgs.callPackage ./playbooks/vllm-container/shell.nix { inherit nixglhost; };
        devShells.nvfp4 = pkgs.callPackage ./playbooks/nvfp4/shell.nix { inherit nixglhost; };
        devShells.vllm-nix = pkgs.callPackage ./playbooks/vllm-nix/shell.nix { inherit nixglhost; };
        devShells.speculative-decoding = pkgs.callPackage ./playbooks/speculative-decoding/shell.nix { inherit nixglhost; };
        devShells.trt-llm = pkgs.callPackage ./playbooks/trt-llm/shell.nix { inherit nixglhost; };
        devShells.nccl-two-sparks = pkgs.callPackage ./playbooks/nccl-two-sparks/shell.nix {
          inherit nixglhost;
        };
        devShells.multi-agent-chatbot = pkgs.callPackage ./playbooks/multi-agent-chatbot/shell.nix { inherit nixglhost; };

        packages.cuda-debug = pkgs.callPackage ./packages/cuda-debug { };
        packages.dgx-dashboard = pkgs.callPackage ./packages/dgx-dashboard { };

        packages.usb-image =
          let
            targetSystem = "aarch64-linux";
          in
          (nixpkgs.lib.nixosSystem {
            system = targetSystem;
            modules = [
              ./usb-configuration.nix
              (
                { modulesPath, ... }:
                {
                  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];
                  isoImage.makeEfiBootable = true;
                  isoImage.makeUsbBootable = true;
                }
              )
              (
                { lib, ... }:
                {
                  nixpkgs.buildPlatform = lib.mkIf (system != targetSystem) {
                    system = system;
                  };
                }
              )
            ];
          }).config.system.build.isoImage;

        packages.default = self.packages.${system}.usb-image;

        # Expose pkgs for downstream flakes to access ComfyUI packages, models, and fetchers
        legacyPackages = {
          inherit pkgs;
        };

        checks.pre-commit-check = pre-commit-check;

        checks.kernel-config-tests = pkgs.runCommand "kernel-config-tests" { src = ./.; } ''
          set -e
          cd $src/tests
          ${pythonForKernelConfig}/bin/python3 -m pytest test_generate_config.py -v
          touch $out
        '';

        apps.pytorch-container = {
          type = "app";
          program = "${pkgs.writeShellScript "pytorch-container" ''
            exec ${pkgs.podman}/bin/podman run --rm -it --device nvidia.com/gpu=all nvcr.io/nvidia/pytorch:25.11-py3 /bin/bash
          ''}";
          meta.description = "Run NVIDIA PyTorch container with GPU support";
        };

        apps.generate-kernel-config = {
          type = "app";
          program = "${pkgs.writeShellScript "generate-kernel-config" ''
            exec ${pythonForKernelConfig}/bin/python3 ${./scripts/generate-terse-dgx-config.py} "$@"
          ''}";
          meta.description = "Generate terse DGX kernel configuration";
        };
      }
    );
}
