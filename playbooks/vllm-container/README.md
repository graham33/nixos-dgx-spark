# vLLM Container Playbook

This playbook provides a Nix devshell for running NVIDIA's vLLM inference server for the Qwen2.5-Math-1.5B-Instruct model.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#vllm
   ```

2. Start the vLLM server:

   ```bash
   vllm-serve-qwen-math
   ```

3. In a separate terminal, test the model:
   ```bash
   nix develop .#vllm
   vllm-test-math "12*17"
   ```

## Available Commands

- `vllm-serve-qwen-math` - Start the vLLM server with the Qwen2.5-Math-1.5B-Instruct model
- `vllm-test-math <query>` - Test the model with a math query (defaults to "12\*17")

## Reference

Based on the NVIDIA DGX Spark playbook: https://build.nvidia.com/spark/vllm/instructions
