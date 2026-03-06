# VS Code on DGX Spark

Develop on the NVIDIA DGX Spark using Visual Studio Code, either natively or
via Remote SSH from your local machine.

## Quick Start

```bash
nix develop .#vscode
```

This provides an SSH-ready environment for connecting to your DGX Spark.

## Option 1: Remote SSH (Recommended)

Use VS Code on your local machine and connect to the DGX Spark over SSH. This
gives you local editor performance with remote compute.

### Prerequisites

- VS Code installed on your local machine
- SSH access to your DGX Spark
- The
  [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
  extension

### Setup

1. Install the **Remote - SSH** extension in VS Code.
2. Open the Command Palette (`Ctrl+Shift+P`) and select
   **Remote-SSH: Connect to Host**.
3. Enter your DGX Spark hostname, e.g. `user@dgxspark.local`.
4. VS Code will install its server component on the remote machine
   automatically.

Alternatively, connect from the command line:

```bash
code --remote ssh-remote+user@dgxspark.local .
```

## Option 2: Native Installation

Install VS Code directly on the DGX Spark for local use with the desktop
environment.

### Steps

1. Download the ARM64 `.deb` package from
   [code.visualstudio.com/download](https://code.visualstudio.com/download).
2. Install with `sudo dpkg -i <package>.deb`.
3. Resolve any dependency issues with `sudo apt-get install -f`.
4. Launch with `code`.

> **Note:** A GUI desktop environment must be active on the DGX Spark for native
> use. Verify with `echo $DISPLAY`.

## Recommended Extensions

- [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) --
  connect to the DGX Spark from your local machine
- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python) --
  Python language support, debugging, and Jupyter notebooks
- [NVIDIA Nsight](https://marketplace.visualstudio.com/items?itemName=nvidia.nsight-vscode-edition) --
  CUDA debugging and profiling
- [Nix IDE](https://marketplace.visualstudio.com/items?itemName=jnoortheen.nix-ide) --
  Nix language support

## References

- [NVIDIA DGX Spark VS Code Instructions](https://build.nvidia.com/spark/vscode/instructions)
- [VS Code Remote SSH Documentation](https://code.visualstudio.com/docs/remote/ssh)
