{ mkShell
, curl
, jq
, podman
}:

mkShell {
  packages = [
    curl
    jq
    podman
  ];

  shellHook = ''
    echo "=== FLUX.1 Dreambooth LoRA Fine-tuning Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/flux-finetuning/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  1. Accept FLUX.1-dev terms at https://huggingface.co/black-forest-labs/FLUX.1-dev"
    echo "  2. Export your HuggingFace token: export HF_TOKEN=<YOUR_TOKEN>"
    echo ""
    echo "Workflow commands:"
    echo "  flux-build-train      Build the training container image"
    echo "  flux-build-comfyui    Build the ComfyUI inference container image"
    echo "  flux-download         Download FLUX.1-dev model weights (30-45 min)"
    echo "  flux-train            Run Dreambooth LoRA fine-tuning (~90 min)"
    echo "  flux-comfyui          Launch ComfyUI for inference (http://localhost:8188)"
    echo ""

    export FLUX_WORKSPACE="''${FLUX_WORKSPACE:-$PWD/flux-workspace}"

    _flux-ensure-workspace() {
      mkdir -p "$FLUX_WORKSPACE"/{models/{vae,loras,checkpoints,text_encoders},flux_data,workflows,outputs}
    }

    flux-build-train() {
      local tmpdir
      tmpdir=$(mktemp -d)
      cat > "$tmpdir/Dockerfile" << 'DOCKERFILE'
    FROM nvcr.io/nvidia/pytorch:25.09-py3
    RUN cd /workspace/ && \
        git clone https://github.com/kohya-ss/sd-scripts.git && \
        cd sd-scripts && \
        git checkout sd3 && \
        pip install -r requirements.txt && \
        apt update && \
        apt install -y libgl1-mesa-dev
    WORKDIR /workspace/sd-scripts
    CMD ["/bin/bash"]
    DOCKERFILE
      echo "Building flux-train image..."
      ${podman}/bin/podman build -f "$tmpdir/Dockerfile" -t flux-train "$tmpdir"
      rm -rf "$tmpdir"
    }

    flux-build-comfyui() {
      local tmpdir
      tmpdir=$(mktemp -d)
      cat > "$tmpdir/Dockerfile" << 'DOCKERFILE'
    FROM nvcr.io/nvidia/pytorch:25.09-py3
    RUN cd /workspace/ && \
        git clone https://github.com/comfyanonymous/ComfyUI.git && \
        cd ComfyUI && \
        git checkout 4ffea0e864275301329ddb5ecc3fbc7211d7a802 && \
        sed -i '/torch/d' requirements.txt && \
        pip install -r requirements.txt && \
        pip install torchsde
    WORKDIR /workspace/ComfyUI
    CMD ["/bin/bash"]
    DOCKERFILE
      echo "Building flux-comfyui image..."
      ${podman}/bin/podman build -f "$tmpdir/Dockerfile" -t flux-comfyui "$tmpdir"
      rm -rf "$tmpdir"
    }

    flux-download() {
      if [ -z "$HF_TOKEN" ]; then
        echo "Error: HF_TOKEN is not set. Export your HuggingFace token first."
        return 1
      fi
      _flux-ensure-workspace

      _download_if_needed() {
        local url="$1" file="$2"
        if [ -f "$file" ]; then
          echo "$file already exists, skipping."
        else
          echo "Downloading $file..."
          ${curl}/bin/curl -C - -L -H "Authorization: Bearer $HF_TOKEN" -o "$file" "$url"
        fi
      }

      _download_if_needed \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
        "$FLUX_WORKSPACE/models/vae/ae.safetensors"
      _download_if_needed \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
        "$FLUX_WORKSPACE/models/checkpoints/flux1-dev.safetensors"
      _download_if_needed \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
        "$FLUX_WORKSPACE/models/text_encoders/clip_l.safetensors"
      _download_if_needed \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
        "$FLUX_WORKSPACE/models/text_encoders/t5xxl_fp16.safetensors"

      echo "Model download complete."
    }

    flux-train() {
      _flux-ensure-workspace
      echo "Starting Dreambooth LoRA fine-tuning..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        --shm-size=8g \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$FLUX_WORKSPACE/flux_data":/workspace/sd-scripts/flux_data \
        -v "$FLUX_WORKSPACE/models/vae":/workspace/sd-scripts/models/vae \
        -v "$FLUX_WORKSPACE/models/loras":/workspace/sd-scripts/models/loras \
        -v "$FLUX_WORKSPACE/models/checkpoints":/workspace/sd-scripts/models/checkpoints \
        -v "$FLUX_WORKSPACE/models/text_encoders":/workspace/sd-scripts/models/text_encoders \
        flux-train \
        bash -c 'accelerate launch \
          --num_processes=1 --num_machines=1 --mixed_precision=bf16 \
          --main_process_ip=127.0.0.1 --main_process_port=29500 \
          --num_cpu_threads_per_process=2 \
          flux_train_network.py \
          --pretrained_model_name_or_path=models/checkpoints/flux1-dev.safetensors \
          --clip_l=models/text_encoders/clip_l.safetensors \
          --t5xxl=models/text_encoders/t5xxl_fp16.safetensors \
          --ae=models/vae/ae.safetensors \
          --dataset_config=flux_data/data.toml \
          --output_dir=models/loras/ \
          --prior_loss_weight=1.0 \
          --output_name=flux_dreambooth \
          --save_model_as=safetensors \
          --network_module=networks.lora_flux \
          --network_dim=256 \
          --network_alpha=256 \
          --learning_rate=1.0 \
          --optimizer_type=Prodigy \
          --lr_scheduler=cosine_with_restarts \
          --gradient_accumulation_steps 4 \
          --gradient_checkpointing \
          --sdpa \
          --max_train_epochs=100 \
          --save_every_n_epochs=25 \
          --mixed_precision=bf16 \
          --guidance_scale=1.0 \
          --timestep_sampling=flux_shift \
          --model_prediction_type=raw \
          --torch_compile \
          --persistent_data_loader_workers \
          --cache_latents \
          --cache_latents_to_disk \
          --cache_text_encoder_outputs \
          --cache_text_encoder_outputs_to_disk'
    }

    flux-comfyui() {
      _flux-ensure-workspace
      echo "Launching ComfyUI at http://localhost:8188 ..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        --shm-size=8g \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$FLUX_WORKSPACE/models/vae":/workspace/ComfyUI/models/vae \
        -v "$FLUX_WORKSPACE/models/loras":/workspace/ComfyUI/models/loras \
        -v "$FLUX_WORKSPACE/models/checkpoints":/workspace/ComfyUI/models/checkpoints \
        -v "$FLUX_WORKSPACE/models/text_encoders":/workspace/ComfyUI/models/text_encoders \
        -v "$FLUX_WORKSPACE/workflows":/workspace/ComfyUI/user/default/workflows \
        flux-comfyui \
        python main.py
    }

    export -f flux-build-train flux-build-comfyui flux-download flux-train flux-comfyui _flux-ensure-workspace
  '';
}
