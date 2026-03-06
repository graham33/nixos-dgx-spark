# Fine-tune with NeMo Playbook

Fine-tune LLMs using the NVIDIA NeMo Automodel framework on the DGX Spark.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#nemo-finetune
   ```

2. Launch the container:

   ```bash
   nix run .#nemo-finetune-container
   ```

3. Inside the container, set up the environment:

   ```bash
   pip3 install uv
   git clone https://github.com/NVIDIA-NeMo/Automodel.git
   cd Automodel
   uv venv --system-site-packages
   uv sync --inexact --frozen --all-extras \
     --no-install-package torch \
     --no-install-package torchvision \
     --no-install-package triton \
     --no-install-package nvidia-cublas-cu12 \
     --no-install-package nvidia-cuda-cupti-cu12 \
     --no-install-package nvidia-cuda-nvrtc-cu12 \
     --no-install-package nvidia-cuda-runtime-cu12 \
     --no-install-package nvidia-cudnn-cu12 \
     --no-install-package nvidia-cufft-cu12 \
     --no-install-package nvidia-cufile-cu12 \
     --no-install-package nvidia-curand-cu12 \
     --no-install-package nvidia-cusolver-cu12 \
     --no-install-package nvidia-cusparse-cu12 \
     --no-install-package nvidia-cusparselt-cu12 \
     --no-install-package nvidia-nccl-cu12 \
     --no-install-package transformer-engine \
     --no-install-package nvidia-modelopt \
     --no-install-package nvidia-modelopt-core \
     --no-install-package flash-attn \
     --no-install-package transformer-engine-cu12 \
     --no-install-package transformer-engine-torch
   ```

4. Build bitsandbytes with ARM64 compute capabilities:

   ```bash
   CMAKE_ARGS="-DCOMPUTE_BACKEND=cuda -DCOMPUTE_CAPABILITY=80;86;87;89;90" \
   CMAKE_BUILD_PARALLEL_LEVEL=8 \
   uv pip install --no-deps git+https://github.com/bitsandbytes-foundation/bitsandbytes.git@50be19c39698e038a1604daf3e1b939c9ac1c342
   ```

5. Verify the installation:

   ```bash
   uv run --frozen --no-sync python -c "import nemo_automodel; print('NeMo AutoModel ready')"
   ```

## Training Examples

Set your HuggingFace token first:

```bash
export HF_TOKEN=<your_huggingface_token>
```

### LoRA Fine-tuning (Llama 3.1 8B)

```bash
uv run --frozen --no-sync \
  examples/llm_finetune/finetune.py \
  -c examples/llm_finetune/llama3_2/llama3_2_1b_squad_peft.yaml \
  --model.pretrained_model_name_or_path meta-llama/Llama-3.1-8B \
  --packed_sequence.packed_sequence_size 1024 \
  --step_scheduler.max_steps 20
```

### QLoRA Fine-tuning (Llama 3 70B)

```bash
uv run --frozen --no-sync \
  examples/llm_finetune/finetune.py \
  -c examples/llm_finetune/llama3_1/llama3_1_8b_squad_qlora.yaml \
  --model.pretrained_model_name_or_path meta-llama/Meta-Llama-3-70B \
  --loss_fn._target_ nemo_automodel.components.loss.te_parallel_ce.TEParallelCrossEntropy \
  --step_scheduler.local_batch_size 1 \
  --packed_sequence.packed_sequence_size 1024 \
  --step_scheduler.max_steps 20
```

### Full Fine-tuning (Qwen3 8B)

```bash
uv run --frozen --no-sync \
  examples/llm_finetune/finetune.py \
  -c examples/llm_finetune/qwen/qwen3_8b_squad_spark.yaml \
  --model.pretrained_model_name_or_path Qwen/Qwen3-8B \
  --step_scheduler.local_batch_size 1 \
  --step_scheduler.max_steps 20 \
  --packed_sequence.packed_sequence_size 1024
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nemo-fine-tune/instructions)
- [NeMo Automodel on GitHub](https://github.com/NVIDIA-NeMo/Automodel)
