# Speculative decoding playbook

Speculative decoding uses a small draft model to accelerate inference of a
larger target model on the DGX Spark GPU. Two methods are available, both
based on TensorRT-LLM.

## Prerequisites

- NVIDIA DGX Spark with GPU
- HuggingFace token: `export HF_TOKEN=<your_token>`

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#speculative-decoding
   ```

2. Start a server (choose one method):

   ```bash
   # EAGLE-3: built-in drafting head with openai/gpt-oss-120b
   spec-eagle3

   # Draft-Target: Llama-3.1-8B drafts for Llama-3.3-70B
   spec-draft-target
   ```

3. In a separate terminal, test the server:

   ```bash
   nix develop .#speculative-decoding
   spec-test-completions "openai/gpt-oss-120b"
   # or for Draft-Target:
   spec-test-completions "nvidia/Llama-3.3-70B-Instruct-FP4"
   ```

## Methods

### EAGLE-3

Uses a built-in drafting head that generates speculative tokens internally,
rather than managing a separate draft model.

- **Model:** `openai/gpt-oss-120b`
- **Drafter:** `nvidia/gpt-oss-120b-Eagle3-long-context`

### Draft-Target

Uses a smaller model to generate candidate tokens which the larger model
verifies in parallel.

- **Target model:** `nvidia/Llama-3.3-70B-Instruct-FP4`
- **Draft model:** `nvidia/Llama-3.1-8B-Instruct-FP4`

## How it works

1. A small **draft model** generates candidate tokens quickly
2. The large **target model** verifies the candidates in parallel
3. Accepted tokens are returned, rejected tokens are regenerated
4. Results in 2-3x faster inference with identical output quality

## Available commands

All commands are available inside `nix develop .#speculative-decoding`:

- `spec-eagle3` - Start EAGLE-3 speculative decoding server
- `spec-draft-target` - Start Draft-Target speculative decoding server
- `spec-shell` - Interactive TensorRT-LLM container shell
- `spec-test-completions <model> [prompt]` - Test the running server

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/speculative-decoding/instructions)
