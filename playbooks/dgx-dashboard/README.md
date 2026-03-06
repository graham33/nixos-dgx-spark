# DGX Dashboard Playbook

The DGX Dashboard is a pre-installed web application on DGX OS that provides a
graphical interface for system updates, GPU telemetry, resource monitoring, and
an integrated JupyterLab environment.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#dgx-dashboard
   ```

2. Open a tunnel to your DGX Spark (for remote access):

   ```bash
   dgx-dashboard-tunnel user@dgxspark.local
   ```

3. Open <http://localhost:11000> in your browser and log in with your DGX Spark
   system credentials.

## Features

- **GPU telemetry** -- real-time monitoring of GPU performance and utilisation
- **System updates** -- install DGX OS and firmware updates
- **JupyterLab** -- launch managed JupyterLab instances with pre-configured
  Python environments

## Remote Access

The devshell provides a `dgx-dashboard-tunnel` helper that forwards port 11000
from the DGX Spark to your local machine via SSH:

```bash
dgx-dashboard-tunnel <user>@<host>
```

### JupyterLab Port Forwarding

JupyterLab runs on a dynamically assigned port. To forward it as well, first
find the port on the DGX Spark:

```bash
cat /opt/nvidia/dgx-dashboard-service/jupyterlab_ports.yaml
```

Then open a tunnel for both ports:

```bash
ssh -L 11000:localhost:11000 -L <JUPYTER_PORT>:localhost:<JUPYTER_PORT> user@dgxspark.local
```

> **Note:** DGX Spark hardware with DGX OS is required. The dashboard is
> pre-installed and does not require a separate container.

> **Future work:** This playbook currently only supports DGX OS. Packaging the
> DGX Dashboard as a Nix derivation so it can run on NixOS is tracked in
> [issue #105](https://github.com/graham33/nixos-dgx-spark/issues/105).

## Reference

- [NVIDIA DGX Dashboard instructions](https://build.nvidia.com/spark/dgx-dashboard/instructions)
