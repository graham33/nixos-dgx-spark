# NVFP4 Quantisation Playbook

NVFP4 quantisation reduces LLM model size with minimal quality loss,
enabling larger models to fit in GPU memory on the DGX Spark.

## Usage

```bash
nix run .#nvfp4-container
```

### What is NVFP4?

NVFP4 (NVIDIA FP4) is a 4-bit floating-point quantisation format that:

- Reduces model memory by ~4x compared to FP16
- Maintains near-original model quality
- Leverages Blackwell GPU hardware support for native FP4 computation

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU-accelerated
> quantisation and inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nvfp4-quantization/instructions)
