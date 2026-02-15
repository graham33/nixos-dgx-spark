# NixOS DGX Spark

[![CI](https://github.com/graham33/nixos-dgx-spark/actions/workflows/ci.yml/badge.svg)](https://github.com/graham33/nixos-dgx-spark/actions/workflows/ci.yml)
[![Cachix](https://img.shields.io/badge/cachix-graham33-blue.svg)](https://graham33.cachix.org)
[![License](https://img.shields.io/github/license/graham33/nixos-dgx-spark)](LICENSE)

NixOS configuration for NVIDIA DGX Spark systems. Provides USB images
and a NixOS module to add settings required for DGX Spark systems.

This works on the NVIDIA DGX Spark itself, and has also been reported to work
on the Asus Ascent GX10.

## USB Boot Image

Build the USB image:

```bash
nix build .#usb-image
sudo dd if=$(echo result/iso/*.iso) of=/dev/your_usb_disk_device bs=1M status=progress
sync
```

The image includes two kernel options, selectable from the GRUB boot menu:

- **NixOS** (default) - NVIDIA's specialized kernel for DGX Spark with full GPU support and working Ethernet
- **NixOS (standard-kernel)** - Standard NixOS 6.17 kernel (Ethernet has problems)

### Booting

Disable Secure Boot in the DGX Spark BIOS and boot from the USB drive.

You can then following the installation instructions in the NixOS manual: https://nixos.org/manual/nixos/stable/#sec-installation-manual

## Using the DGX Spark module

This module provides configurable DGX Spark hardware support with options for kernel selection.

### Module Configuration Options

```nix
hardware.dgx-spark = {
  enable = true;                 # Enable DGX Spark hardware support
  useNvidiaKernel = true;        # Use NVIDIA kernel (default: true)
};
```

### Using Standard NixOS Kernel (Recommended for Most Users)

```nix
hardware.dgx-spark = {
  enable = true;
  useNvidiaKernel = false;       # Use standard NixOS 6.17 kernel
};
```

### Using NVIDIA Kernel (For Specialized GPU Workloads)

```nix
hardware.dgx-spark.enable = true;  # Uses NVIDIA kernel by default
```

The NVIDIA kernel is a custom build optimized for NVIDIA DGX Spark systems. The kernel configuration is generated from NVIDIA's Debian annotations using `scripts/generate-dgx-config.py` and compared with NixOS defaults using `scripts/compare-configs.py` to ensure compatibility.

### Importing in Other Projects

Other projects can import this flake and use the DGX Spark module:

```nix
{
  inputs.dgx-spark.url = "github:graham33/nixos-dgx-spark";

  outputs = { nixpkgs, dgx-spark, ... }: {
    nixosConfigurations.mySystem = nixpkgs.lib.nixosSystem {
      modules = [
        dgx-spark.nixosModules.dgx-spark
        {
          # Enable DGX Spark support
          hardware.dgx-spark.enable = true;
          # Optionally use standard kernel: useNvidiaKernel = false;
        }
        # your other modules
      ];
    };
  };
}
```

## Quick Start NixOS Template

For a complete NixOS configuration template specifically designed for DGX Spark
systems, you can use the template:

```bash
# Create a new directory for your NixOS configuration
mkdir my-dgx-spark-config
cd my-dgx-spark-config

# Initialize with the DGX Spark template
nix flake init -t github:graham33/nixos-dgx-spark#dgx-spark
```

This will create a complete NixOS configuration with:

- `flake.nix` - Flake configuration that imports the DGX Spark module
- `configuration.nix` - Main system configuration optimized for DGX Spark
- `hardware-configuration.nix` - Hardware configuration template

### Customizing the Template

After initializing the template, you'll need to:

1. **Generate hardware configuration and update template:**

   ```bash
   # Generate hardware config to a temporary location to get the real UUIDs
   sudo nixos-generate-config --root /mnt --dir /tmp/nixos-config

   # Copy the real hardware UUIDs and settings from the generated file
   # Replace the placeholder UUIDs in hardware-configuration.nix with actual
   # values from /tmp/nixos-config/hardware-configuration.nix
   ```

2. **Edit `configuration.nix` to customize:**
   - Change hostname from `dgx-spark` to your preferred name
   - Update username from `nixos` to your preferred username
   - Add your SSH public keys for remote access
   - Set your timezone and locale preferences
   - Add any additional packages you need

3. **Deploy the configuration to /etc/nixos:**

   ```bash
   # Copy your configuration to /etc/nixos
   sudo cp -r . /etc/nixos/

   # Apply the configuration
   sudo nixos-rebuild switch --flake /etc/nixos#dgx-spark
   ```

## Playbooks

This repository includes devshells for various NVIDIA DGX Spark playbooks from https://build.nvidia.com/spark:

- [ComfyUI](./playbooks/comfyui/README.md) - Run ComfyUI with Stable Diffusion 1.5 for AI image generation
- [vLLM Container](./playbooks/vllm-container/README.md) - Run vLLM inference server with Qwen2.5-Math-1.5B-Instruct model
- [vLLM Nix](./playbooks/vllm-nix/README.md) - Run vLLM inference server natively with Qwen2.5-Math-1.5B-Instruct model (Nix native, no containers)

## Caching

Unfortunately CUDA packages are not currently cached by the NixOS default
caches. There are community caches, but they currently don't provide
aarch64-linux packages. See https://nixos.wiki/wiki/CUDA for general caching
details.

## License

MIT License - see [LICENSE](LICENSE) for details.
