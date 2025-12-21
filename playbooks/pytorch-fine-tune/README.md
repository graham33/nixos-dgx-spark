# PyTorch Fine-Tuning Nix Playbook

Native Nix implementation of the [NVIDIA PyTorch Fine-Tune Playbook](https://build.nvidia.com/spark/pytorch-fine-tune).

## Overview

This playbook provides a Nix devShell with all dependencies needed to run the NVIDIA PyTorch fine-tuning scripts. Scripts are fetched directly from the [NVIDIA DGX Spark Playbooks repository](https://github.com/NVIDIA/dgx-spark-playbooks).

For complete instructions on using the playbook, see the [NVIDIA documentation](https://build.nvidia.com/spark/pytorch-fine-tune/instructions).

## Quick Start

1. **Enter the development shell:**

   ```bash
   nix develop .#pytorch-fine-tune
   ```

2. **Authenticate with HuggingFace:**

   ```bash
   hf auth login
   ```

3. **Run the fine-tuning scripts:**

   ```bash
   # LoRA fine-tuning (Llama3.1-8B)
   python $LLAMA3_8B_LORA_SCRIPT

   # Full fine-tuning (Llama3.2-3B)
   python $LLAMA3_3B_FULL_SCRIPT
   ```

Both scripts accept command-line arguments. Run with `--help` to see all options.

The script paths are available via environment variables:

- `$LLAMA3_8B_LORA_SCRIPT` - LoRA fine-tuning script
- `$LLAMA3_3B_FULL_SCRIPT` - Full fine-tuning script

## Nix-Specific Details

### Dependencies

All dependencies are provided through Nix:

- **Python packages**: torch, transformers, datasets, peft, trl, bitsandbytes, accelerate, huggingface-hub
- **GPU support**: All packages built with CUDA support from existing overlays
- **Scripts**: Fetched from NVIDIA repository at build time (commit `70bbbbfab8907551902114809bb143cf3c5b05fd`)

### Model Cache

Models are downloaded to `~/.cache/huggingface/` and reused across runs.

**Expected storage:**

- Llama3.1-8B: ~16GB
- Llama3.2-3B: ~6GB

To clear the cache:

```bash
rm -rf ~/.cache/huggingface/hub/models--meta-llama*
```

### Differences from Container Version

- ✅ **Native Nix packages** - No Docker/Podman required
- ✅ **Reproducible environment** - Pinned package versions via flake.lock
- ✅ **GPU support** - All packages built with CUDA support
- ❌ **Single-node only** - Multi-node Docker Swarm setup not included

## Reference

- [NVIDIA PyTorch Fine-Tune Playbook](https://build.nvidia.com/spark/pytorch-fine-tune)
- [NVIDIA DGX Spark Playbooks Repository](https://github.com/NVIDIA/dgx-spark-playbooks)
- [Hugging Face Documentation](https://huggingface.co/docs)
