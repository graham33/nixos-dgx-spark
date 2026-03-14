# DGX Dashboard Playbook

The DGX Dashboard is a web application that provides a graphical interface for
system updates, GPU telemetry, resource monitoring, and an integrated JupyterLab
environment.

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

## NixOS Module

To run the DGX Dashboard on NixOS, add the module to your configuration:

```nix
{
  imports = [ dgx-spark.nixosModules.dgx-dashboard ];

  services.dgx-dashboard = {
    enable = true;
    port = 11000; # default
  };
}
```

This sets up:

- A dedicated service user and group
- Two systemd services (`dgx-dashboard` and `dgx-dashboard-admin`)
- D-Bus policy for the admin service
- Log rotation

> **Note:** The dashboard binaries are aarch64-only. This module only works on
> `aarch64-linux` systems.

## Running Locally

On an aarch64-linux system, you can run the dashboard directly from the
devshell:

```bash
nix develop .#dgx-dashboard
dashboard-service -port 11000 serve
```

Then open <http://localhost:11000> in your browser.

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

## Reference

- [NVIDIA DGX Dashboard instructions](https://build.nvidia.com/spark/dgx-dashboard/instructions)
