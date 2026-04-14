# PyTorch fine-tuning (Nix) playbook

Fine-tune LLMs using native PyTorch and HuggingFace PEFT on the DGX Spark. Nix provides all dependencies.

## Usage

```bash
nix develop /path/to/nixos-dgx-spark#pytorch-finetune-nix
pytorch-finetune-setup
python Llama3_8B_LoRA_finetuning.py
```

### Prerequisites

1. Accept the model license on HuggingFace (e.g. [meta-llama/Llama-3.1-8B](https://huggingface.co/meta-llama/Llama-3.1-8B))
2. Run `huggingface-cli login` with your access token

### Features

- Fully reproducible Nix environment (no containers or runtime pip installs)
- PyTorch with CUDA support
- HuggingFace Transformers, PEFT, TRL, Datasets, and Accelerate
- BitsAndBytes for 4-bit/8-bit quantisation (QLoRA)
- NVIDIA fine-tuning scripts from [dgx-spark-playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)

### Available training scripts

| Script                           | Description                        |
| -------------------------------- | ---------------------------------- |
| `Llama3_3B_full_finetuning.py`   | Full fine-tuning of Llama 3 3B     |
| `Llama3_8B_LoRA_finetuning.py`   | LoRA fine-tuning of Llama 3 8B     |
| `Llama3_70B_LoRA_finetuning.py`  | LoRA fine-tuning of Llama 3.1 70B  |
| `Llama3_70B_qLoRA_finetuning.py` | QLoRA fine-tuning of Llama 3.1 70B |

DGX Spark hardware with an NVIDIA GPU is required for training.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/pytorch-fine-tune/instructions)
