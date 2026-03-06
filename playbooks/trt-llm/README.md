# TRT-LLM for Inference Playbook

NVIDIA TensorRT-LLM provides highly optimised LLM inference with kernel
fusion and quantisation on the DGX Spark.

## Prerequisites

- A HuggingFace token with access to the model (`export HF_TOKEN=<your-token>`)
- DGX Spark hardware with NVIDIA GPU

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#trt-llm
   ```

2. Validate the TensorRT-LLM installation:

   ```bash
   trt-llm-validate
   ```

3. Start the OpenAI-compatible server:

   ```bash
   trt-llm-serve
   ```

4. In a separate terminal, test the server:

   ```bash
   nix develop .#trt-llm
   trt-llm-test "What is the capital of France?"
   ```

## Available Commands

- `trt-llm-validate` - Verify the TensorRT-LLM container and GPU access
- `trt-llm-quickstart [MODEL]` - Run a quick inference test without starting a server
- `trt-llm-serve [MODEL]` - Start an OpenAI-compatible API server (port 8355)
- `trt-llm-test [PROMPT]` - Send a chat completion request to the running server

## Container App

You can also launch the container directly:

```bash
nix run .#trt-llm-container
```

## Default Model

The default model is `nvidia/Llama-3.1-8B-Instruct-FP4`, an FP4-quantised
Llama 3.1 8B model optimised for TensorRT-LLM inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/trt-llm/instructions)
- [TensorRT-LLM on GitHub](https://github.com/NVIDIA/TensorRT-LLM)
