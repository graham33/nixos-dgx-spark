# Unsloth on DGX Spark Playbook

Unsloth provides 2x faster LoRA fine-tuning with 60% less memory usage on
the DGX Spark.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#unsloth
   ```

2. Launch the Unsloth container:

   ```bash
   unsloth-start
   ```

   This pulls the `nvcr.io/nvidia/pytorch:25.11-py3` image, installs Unsloth
   and its dependencies, and drops you into a shell ready for fine-tuning.

3. Inside the container, verify GPU access:

   ```bash
   nvidia-smi
   python -c "import torch; print(torch.cuda.get_device_name())"
   ```

## HuggingFace Cache

The container mounts your local HuggingFace cache directory so that
downloaded models persist between runs. Set `HF_HOME` to override the
default location (`~/.cache/huggingface`).

## Advantages

- **2x faster** than standard LoRA fine-tuning
- **60% less memory** usage
- Zero accuracy loss compared to standard training
- Supports Llama, Mistral, Qwen, Gemma, and more

> **Note:** DGX Spark hardware with NVIDIA GPU is required for training.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/unsloth/instructions)
- [Unsloth on GitHub](https://github.com/unslothai/unsloth)
