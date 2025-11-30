# ComfyUI Playbook

This playbook provides a Nix devshell for running ComfyUI with NVIDIA GPU support and the Stable Diffusion 1.5 model pre-installed.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#comfyui
   ```

2. Start ComfyUI:

   ```bash
   comfyui --listen 0.0.0.0
   ```

3. Access the web interface at `http://<IP>:8188`

## Pre-installed Models

- **Stable Diffusion 1.5** (fp16, ~2GB) - General-purpose image generation

## Testing

1. In the web interface, click **Templates** -> **Getting Started** -> **Image Generation**
2. Click **Run** to generate an image
3. Generation takes less than 10 seconds on DGX Spark

## Reference

Based on the NVIDIA DGX Spark playbook: https://build.nvidia.com/spark/comfy-ui/instructions

Powered by [nixified.ai](https://nixified.ai/)
