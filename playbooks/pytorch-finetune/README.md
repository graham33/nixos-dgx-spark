# Fine-tune with PyTorch Playbook

Fine-tune LLMs using native PyTorch and HuggingFace PEFT on the DGX Spark.

## Usage

```bash
nix develop /home/graham/playbooks#pytorch-finetune
pytorch-finetune
```

### Features

- Native PyTorch training loop with GPU acceleration
- HuggingFace PEFT for LoRA and QLoRA fine-tuning
- HuggingFace model cache persisted via volume mount
- TorchRun for distributed training

### Volume Mounts

- `$PWD` → `/workspace` (training data and scripts)
- `$HOME/.cache/huggingface` → `/root/.cache/huggingface` (model cache)

> **Note:** DGX Spark hardware with NVIDIA GPU is required for training.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/pytorch-fine-tune/instructions)
