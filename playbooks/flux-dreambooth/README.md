# FLUX.1 Dreambooth LoRA fine-tuning playbook

Fine-tune the FLUX.1-dev 12B image generation model using Dreambooth LoRA on
DGX Spark, then generate images with ComfyUI.

## Prerequisites

- NVIDIA DGX Spark with GPU
- Accept the [FLUX.1-dev model terms](https://huggingface.co/black-forest-labs/FLUX.1-dev)
- Generate a [HuggingFace token](https://huggingface.co/settings/tokens) and
  export it:
  ```bash
  export HF_TOKEN=<YOUR_TOKEN>
  ```

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#flux-dreambooth
   ```

2. Build the container images (one-time):

   ```bash
   flux-build-train
   flux-build-comfyui
   ```

3. Download model weights (~30-45 minutes, one-time). This writes to a
   `flux-workspace` directory in your current working directory. Override
   the location with `export FLUX_WORKSPACE=/path/to/workspace`:

   ```bash
   flux-download
   ```

4. Prepare your training dataset in `flux-workspace/flux_data/` with a
   `data.toml` configuration (5-10 images per concept recommended).

5. Run fine-tuning (~90 minutes):

   ```bash
   flux-train
   ```

6. Launch ComfyUI for inference:

   ```bash
   flux-comfyui
   ```

   Open <http://localhost:8188> in your browser.

## Available commands

| Command              | Description                                               |
| -------------------- | --------------------------------------------------------- |
| `flux-build-train`   | Build the training container image                        |
| `flux-build-comfyui` | Build the ComfyUI inference container image               |
| `flux-download`      | Download FLUX.1-dev model weights                         |
| `flux-train`         | Run Dreambooth LoRA fine-tuning                           |
| `flux-comfyui`       | Launch ComfyUI for image generation                       |
| `flux-pytorch-shell` | Drop into a bare PyTorch container with workspace mounted |

## Workspace layout

All data is stored under `$FLUX_WORKSPACE` (defaults to `$PWD/flux-workspace`):

```
flux-workspace/
  models/
    checkpoints/   # FLUX.1-dev base model
    text_encoders/ # CLIP-L and T5-XXL encoders
    vae/           # Autoencoder
    loras/         # Fine-tuned LoRA weights (output)
  flux_data/       # Training images and data.toml
  workflows/       # ComfyUI workflow files
  outputs/         # Generated images
```

## Dataset configuration

Create `flux-workspace/flux_data/data.toml` to define your training concepts.
Example:

```toml
[general]
shuffle_caption = true
caption_extension = ".txt"

[[datasets]]
resolution = 512
batch_size = 1
keep_tokens = 1

  [[datasets.subsets]]
  image_dir = "flux_data/my_concept"
  class_tokens = "myconcept thing"
  num_repeats = 10
```

Place 5-10 images per concept in the corresponding subdirectory.

## Memory management

DGX Spark uses a Unified Memory Architecture (UMA). To free cached memory
after stopping containers:

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/flux-finetuning/instructions)
- [NVIDIA DGX Spark Playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)
- [FLUX.1-dev on HuggingFace](https://huggingface.co/black-forest-labs/FLUX.1-dev)
