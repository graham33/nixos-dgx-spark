{
  description = "NixOS USB disk image for aarch64-linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
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

  outputs =
    { self
    , nixpkgs
    , flake-utils
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

        devShells.comfyui = pkgs.callPackage ./playbooks/comfyui/shell.nix { };
        devShells.vllm-container = pkgs.callPackage ./playbooks/vllm-container/shell.nix { };
        devShells.vllm-nix = pkgs.callPackage ./playbooks/vllm-nix/shell.nix { };
        devShells.speculative-decoding = pkgs.callPackage ./playbooks/speculative-decoding/shell.nix { };

        packages.cuda-debug = pkgs.callPackage ./packages/cuda-debug { };

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

        apps.speculative-decoding-eagle3 = {
          type = "app";
          program = "${pkgs.writeShellScript "speculative-decoding-eagle3" ''
            if [ -z "$HF_TOKEN" ]; then
              echo "Error: HF_TOKEN environment variable must be set."
              echo "Get a token from https://huggingface.co/settings/tokens"
              exit 1
            fi
            exec ${pkgs.podman}/bin/podman run \
              -e HF_TOKEN="$HF_TOKEN" \
              -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
              --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
              --device nvidia.com/gpu=all --ipc=host --network host \
              nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6 \
              bash -c '
                hf download openai/gpt-oss-120b && \
                hf download nvidia/gpt-oss-120b-Eagle3-long-context \
                    --local-dir /opt/gpt-oss-120b-Eagle3/ && \
                cat > /tmp/extra-llm-api-config.yml <<INNER_EOF
            enable_attention_dp: false
            disable_overlap_scheduler: false
            enable_autotuner: false
            cuda_graph_config:
                max_batch_size: 1
            speculative_config:
                decoding_type: Eagle
                max_draft_len: 5
                speculative_model_dir: /opt/gpt-oss-120b-Eagle3/
            kv_cache_config:
                free_gpu_memory_fraction: 0.9
                enable_block_reuse: false
            INNER_EOF
                export TIKTOKEN_ENCODINGS_BASE="/tmp/harmony-reqs" && \
                mkdir -p $TIKTOKEN_ENCODINGS_BASE && \
                wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken && \
                wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken
                trtllm-serve openai/gpt-oss-120b \
                  --backend pytorch --tp_size 1 \
                  --max_batch_size 1 \
                  --extra_llm_api_options /tmp/extra-llm-api-config.yml'
          ''}";
          meta.description = "Run EAGLE-3 speculative decoding with GPU support";
        };

        apps.speculative-decoding-draft-target = {
          type = "app";
          program = "${pkgs.writeShellScript "speculative-decoding-draft-target" ''
            if [ -z "$HF_TOKEN" ]; then
              echo "Error: HF_TOKEN environment variable must be set."
              echo "Get a token from https://huggingface.co/settings/tokens"
              exit 1
            fi
            exec ${pkgs.podman}/bin/podman run \
              -e HF_TOKEN="$HF_TOKEN" \
              -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
              --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
              --device nvidia.com/gpu=all --ipc=host --network host \
              nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6 \
              bash -c "
                hf download nvidia/Llama-3.3-70B-Instruct-FP4 && \
                hf download nvidia/Llama-3.1-8B-Instruct-FP4 \
                    --local-dir /opt/Llama-3.1-8B-Instruct-FP4/ && \
                cat <<INNER_EOF > extra-llm-api-config.yml
            print_iter_log: false
            disable_overlap_scheduler: true
            speculative_config:
              decoding_type: DraftTarget
              max_draft_len: 4
              speculative_model_dir: /opt/Llama-3.1-8B-Instruct-FP4/
            kv_cache_config:
              enable_block_reuse: false
            INNER_EOF
                trtllm-serve nvidia/Llama-3.3-70B-Instruct-FP4 \
                  --backend pytorch --tp_size 1 \
                  --max_batch_size 1 \
                  --kv_cache_free_gpu_memory_fraction 0.9 \
                  --extra_llm_api_options ./extra-llm-api-config.yml
              "
          ''}";
          meta.description = "Run Draft-Target speculative decoding with GPU support";
        };

        apps.speculative-decoding-container = {
          type = "app";
          program = "${pkgs.writeShellScript "speculative-decoding-container" ''
            exec ${pkgs.podman}/bin/podman run --rm -it \
              --device nvidia.com/gpu=all --ipc=host --network host \
              -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
              nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6 /bin/bash
          ''}";
          meta.description = "Run TensorRT-LLM container with GPU support for speculative decoding";
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
