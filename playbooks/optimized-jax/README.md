# Optimised JAX Playbook

GPU-optimised JAX for high-performance machine learning on the DGX Spark.

## Usage

### Container

```bash
nix run .#optimized-jax-container
```

### Nix-native

```bash
nix develop .#optimized-jax
python -c 'import jax; print(jax.devices())'
```

### Features

- XLA compilation for optimal GPU utilisation
- JIT compilation of numerical functions
- Automatic differentiation
- GPU-accelerated linear algebra

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU acceleration.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/jax/instructions)
- [JAX Documentation](https://jax.readthedocs.io/)
