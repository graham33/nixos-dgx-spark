# NVFP4 Quantisation Playbook

NVFP4 quantisation reduces LLM model size with minimal quality loss,
enabling larger models to fit in GPU memory on the DGX Spark.

## Usage

```bash
nix develop .#nvfp4
```

### Available commands

| Command                  | Description                                |
| ------------------------ | ------------------------------------------ |
| `nvfp4-start`            | Start an interactive container shell       |
| `nvfp4-quantize [MODEL]` | Quantize a model to NVFP4 format           |
| `nvfp4-validate`         | Check quantized model output files         |
| `nvfp4-test [MODEL]`     | Test-load the quantized model              |
| `nvfp4-serve [MODEL]`    | Serve the model with OpenAI-compatible API |
| `nvfp4-chat [PROMPT]`    | Send a chat request to the running server  |
| `nvfp4-cleanup`          | Remove output models and cached data       |

The default model is `deepseek-ai/DeepSeek-R1-Distill-Llama-8B`. Pass a
different model name to `nvfp4-quantize`, `nvfp4-test`, or `nvfp4-serve`
to work with other models.

### Typical workflow

```bash
# Set your Hugging Face token
export HF_TOKEN="your_token_here"

# Enter the devShell
nix develop .#nvfp4

# Quantize the default model (~45-90 min)
nvfp4-quantize

# Check the output files
nvfp4-validate

# Quick test that the model loads
nvfp4-test

# Serve with OpenAI-compatible API (in one terminal)
nvfp4-serve

# Chat with the model (in another terminal)
nvfp4-chat "What is artificial intelligence?"
```

### What is NVFP4?

NVFP4 (NVIDIA FP4) is a 4-bit floating-point quantisation format that:

- Reduces model memory ~3.5x compared to FP16 and ~1.8x compared to FP8
- Maintains near-original model quality (typically less than 1% degradation)
- Leverages Blackwell GPU hardware support for native FP4 computation

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU-accelerated
> quantisation and inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nvfp4-quantization/instructions)
