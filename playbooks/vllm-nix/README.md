# vLLM Nix Playbook

This playbook provides a Nix devshell for running vLLM inference server directly from nixpkgs (no containers) for the Qwen2.5-Math-1.5B-Instruct model.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#vllm-nix
   ```

2. Start the vLLM server:

   ```bash
   vllm-serve-qwen-math
   ```

3. In a separate terminal, test the model:
   ```bash
   nix develop .#vllm-nix
   vllm-test-math "12*17"
   ```

## Available Commands

- `vllm-serve-qwen-math` - Start the vLLM server with the Qwen2.5-Math-1.5B-Instruct model
- `vllm-test-math <query>` - Test the model with a math query (defaults to "12\*17")

## Differences from Container Version

- Uses vLLM directly from nixpkgs instead of NVIDIA containers
- No podman/container runtime required
- Simpler setup with native nix packages
- Same API compatibility and usage patterns

## Reference

Based on the vllm-container playbook but using native nix packages.
