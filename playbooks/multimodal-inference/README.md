# Multi-modal Inference Playbook

Run text-to-image inference models (Flux.1, SDXL) on the DGX Spark using NVIDIA's
TensorRT Diffusion demos inside the PyTorch container.

## Prerequisites

- A [Hugging Face](https://huggingface.co/) account with an access token
- Access granted to [black-forest-labs/FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev) and its ONNX variant

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#multimodal-inference
   ```

2. Launch the container with GPU support (pulls the image, clones TensorRT, and
   installs Flux dependencies automatically):

   ```bash
   multimodal-inference-container
   ```

3. Inside the container, generate an image:

   ```bash
   export HF_TOKEN=<your-token>
   python3 demo_txt2img_flux.py "a beautiful photograph of Mt. Fuji during cherry blossom" \
     --hf-token=$HF_TOKEN --bf16 --download-onnx-models
   ```

## Supported Models

| Model          | Script                 | Notes                        |
| -------------- | ---------------------- | ---------------------------- |
| Flux.1 Dev     | `demo_txt2img_flux.py` | Default; BF16 or FP8         |
| Flux.1 Schnell | `demo_txt2img_flux.py` | `--version="flux.1-schnell"` |
| SDXL (xl-1.0)  | `demo_txt2img_xl.py`   | `--version xl-1.0`           |

> **Note:** FP16 Flux.1 Schnell requires more than 48 GB VRAM for native export.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/multi-modal-inference/instructions)
