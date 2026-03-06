# Single-cell RNA Sequencing Playbook

GPU-accelerated single-cell RNA sequencing analysis using NVIDIA RAPIDS on the
DGX Spark.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#scrna-seq
   ```

2. Launch the RAPIDS notebook container:

   ```bash
   scrna-seq-start
   ```

3. Access JupyterLab at **http://localhost:8888**.

## Container

Image: `nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13`

### Included Tools

- **rapids-singlecell** — GPU-accelerated scRNA-seq analysis
- **scanpy** — single-cell analysis in Python
- **cuDF / cuML / cuGraph** — GPU DataFrames, ML, and graph analytics

### Exposed Ports

| Port | Service    |
| ---- | ---------- |
| 8888 | JupyterLab |
| 8787 | Dask       |
| 8786 | Dask       |
| 8501 | Streamlit  |
| 8050 | Dash       |

### Data Formats

Supports `.h5ad` (AnnData) format for single-cell datasets.

> **Note:** DGX Spark hardware with an NVIDIA GPU is required for
> GPU-accelerated analysis.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/single-cell/instructions)
- [Closes #46](https://github.com/graham33/nixos-dgx-spark/issues/46)
