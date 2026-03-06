# Portfolio Optimisation Playbook

GPU-accelerated portfolio optimisation using NVIDIA RAPIDS on the DGX Spark.
Use cuDF, cuML, and cuGraph to analyse financial data and optimise portfolios
entirely on the GPU.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#portfolio-optimization
   ```

2. Start the RAPIDS JupyterLab environment:

   ```bash
   portfolio-start
   ```

3. Open JupyterLab at **http://localhost:8888** and select the
   "Portfolio Optimization" kernel.

Alternatively, run the container directly:

```bash
nix run .#portfolio-optimization-container
```

## Available Commands

- `portfolio-start` - Launch the RAPIDS notebook container with GPU support

## Requirements

- DGX Spark with NVIDIA GPU
- At least 40 GB unified memory free
- 30 GB available storage

## Features

- GPU-accelerated financial data analysis with cuDF
- Portfolio optimisation algorithms on GPU
- Risk analysis and Monte Carlo simulations

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/portfolio-optimization/instructions)
