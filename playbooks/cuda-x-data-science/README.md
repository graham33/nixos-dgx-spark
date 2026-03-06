# CUDA-X Data Science Playbook

GPU-accelerated data science using the NVIDIA RAPIDS ecosystem on the DGX
Spark.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#cuda-x-data-science
   ```

2. Launch the RAPIDS notebooks container:

   ```bash
   nix run .#cuda-x-data-science-container
   ```

3. Access JupyterLab at **http://localhost:8888**.

## Container

The playbook uses the `rapidsai/notebooks:25.12-cuda13-py3.12` image, which
includes JupyterLab and the full RAPIDS ecosystem pre-installed:

| Library   | Purpose                          |
| --------- | -------------------------------- |
| cuDF      | GPU DataFrames (pandas-like API) |
| cuML      | GPU Machine Learning             |
| cuGraph   | GPU Graph Analytics              |
| cuSpatial | GPU Spatial Analytics            |

The container exposes port 8888 for JupyterLab and mounts the current working
directory at `/workspace`.

> **Note:** DGX Spark hardware with an NVIDIA GPU is required for
> GPU-accelerated data science.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/cuda-x-data-science/instructions)
- [RAPIDS Documentation](https://docs.rapids.ai/)
