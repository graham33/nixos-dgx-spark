# DGX Dashboard Playbook

The DGX Dashboard is a web application that provides a graphical interface for
GPU telemetry, resource monitoring, and an integrated JupyterLab environment.

## Access

- **DGX OS**: The dashboard is pre-installed. Open <http://localhost:11000> and
  log in with your system credentials.
- **NixOS**: Use the `nixos-dgx-spark` module, which enables the dashboard
  automatically. See the [NixOS module documentation](../../README.md#using-the-dgx-spark-module).

## Features

- **GPU telemetry** -- real-time monitoring of GPU performance and utilisation
- **System updates** -- install DGX OS and firmware updates
- **JupyterLab** -- launch managed JupyterLab instances with pre-configured
  Python environments

## Reference

- [NVIDIA DGX Dashboard instructions](https://build.nvidia.com/spark/dgx-dashboard/instructions)
