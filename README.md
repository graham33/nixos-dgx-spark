# Nix and NixOS on the DGX Spark

[![CI](https://github.com/graham33/nixos-dgx-spark/actions/workflows/ci.yml/badge.svg)](https://github.com/graham33/nixos-dgx-spark/actions/workflows/ci.yml)
[![Cachix](https://img.shields.io/badge/cachix-graham33-blue.svg)](https://graham33.cachix.org)
[![License](https://img.shields.io/github/license/graham33/nixos-dgx-spark)](LICENSE)

Try DGX Spark playbooks using Nix on DGX OS, or install NixOS on your DGX
Spark for the full Nix experience. The repository provides USB images and a
NixOS module with settings for DGX Spark systems.

This works on the NVIDIA DGX Spark itself and also on the Asus Ascent GX10.

See my 5 minute lightning talk from [Planet Nix](https://planetnix.com) for an intro:
 https://youtu.be/AvK_gi_snJE?si=MPKv3iiuS9B5elIE

## Using Nix on DGX OS (Ubuntu)

You can use the dev shells and playbooks in this repo on NVIDIA DGX OS (Ubuntu)
without installing NixOS.

### Setup

1. **Install Nix** using the [official installer](https://nixos.org/download/):

   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

   Alternatively, you can use the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Enable flakes and nix-command** by adding to `/etc/nix/nix.conf`:

   ```
   experimental-features = nix-command flakes
   ```

3. **Enable the graham33 Cachix cache** — see [Caching](#caching) below.

### Running on Non-NixOS (e.g. DGX OS)

On non-NixOS systems, Nix-built CUDA applications need
[nix-gl-host](https://github.com/numtide/nix-gl-host) to find the host GPU
drivers. The playbook devshells handle this automatically — container-based
playbooks don't need it, and Nix-native playbooks wrap their commands with
`nixglhost` so no manual intervention is required.

For other devshells (e.g. `cuda`), `nixglhost` is available and can be used
to prefix commands manually:

```bash
nix develop .#cuda
nixglhost deviceQuery
```

## NixOS on the DGX Spark

> [!WARNING]
> Only DGX OS can boot from the factory firmware. You need to
> [update firmware](#firmware-updates) before installing NixOS.

### USB Boot Image

Build the USB image:

```bash
nix build .#usb-image
sudo dd if=$(echo result/iso/*.iso) of=/dev/your_usb_disk_device bs=1M status=progress
sync
```

The image includes two kernel options, selectable from the GRUB boot menu:

- **NixOS** (default) - NVIDIA's specialised kernel for DGX Spark with full GPU support and working Ethernet
- **NixOS (standard-kernel)** - Standard NixOS 6.17 kernel (Ethernet has problems)

#### Booting

Disable Secure Boot in the DGX Spark BIOS and boot from the USB drive.

You can then follow the installation instructions in the NixOS manual: https://nixos.org/manual/nixos/stable/#sec-installation-manual

### Using the DGX Spark module

This module provides configurable DGX Spark hardware support with options for kernel selection.

#### Module configuration options

```nix
hardware.dgx-spark = {
  enable = true;                 # Enable DGX Spark hardware support
  useNvidiaKernel = true;        # Use NVIDIA kernel (default: true)
};
```

#### Using NVIDIA kernel

```nix
hardware.dgx-spark.enable = true;  # Uses NVIDIA kernel by default
```

The NVIDIA kernel is a custom build optimised for NVIDIA DGX Spark systems. The kernel configuration is generated from NVIDIA's Debian annotations and compared with NixOS defaults to produce a minimal, maintainable configuration.

The module also enables the DGX Dashboard web interface at
<http://localhost:11000>, providing GPU telemetry and system monitoring.

#### Using standard NixOS kernel (has some issues with networking)

```nix
hardware.dgx-spark = {
  enable = true;
  useNvidiaKernel = false;       # Use standard NixOS 6.17 kernel
};
```

#### Kernel configuration management

The kernel configuration is generated from NVIDIA's Debian annotations and stored in `kernel-configs/nvidia-dgx-spark-<version>.nix`. This terse configuration only contains options that differ from NixOS defaults, reducing verbosity by ~82%.

To regenerate the kernel configuration:

```bash
nix run .#generate-kernel-config
```

This:

1. Fetches the NVIDIA kernel source from GitHub
2. Builds the NixOS baseline kernel config
3. Compares NVIDIA's annotations with NixOS defaults
4. Generates a terse config file with only the differences

Regeneration is needed when:

- NVIDIA kernel version changes (update `kernel-configs/nvidia-kernel-source.nix`)
- NixOS common-config changes (nixpkgs update)

You can also use a local kernel source for development:

```bash
nix run .#generate-kernel-config -- --kernel-source /path/to/NV-Kernels
```

#### Importing in other projects

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

### Quick start NixOS template

For a complete NixOS configuration template specifically designed for DGX Spark
systems, you can use the template:

```bash
# Create a new directory for your NixOS configuration
mkdir my-dgx-spark-config
cd my-dgx-spark-config

# Initialise with the DGX Spark template
nix flake init -t github:graham33/nixos-dgx-spark#dgx-spark
```

This creates a complete NixOS configuration with:

- `flake.nix` - Flake configuration that imports the DGX Spark module
- `configuration.nix` - Main system configuration optimised for DGX Spark
- `hardware-configuration.nix` - Hardware configuration template

#### Customising the template

After initialising the template, you need to:

1. **Generate hardware configuration and update template:**

   ```bash
   # Generate hardware config to a temporary location to get the real UUIDs
   sudo nixos-generate-config --root /mnt --dir /tmp/nixos-config

   # Copy the real hardware UUIDs and settings from the generated file
   # Replace the placeholder UUIDs in hardware-configuration.nix with actual
   # values from /tmp/nixos-config/hardware-configuration.nix
   ```

2. **Edit `configuration.nix` to customise:**
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

### Firmware updates

As [noted](https://github.com/graham33/nixos-dgx-spark/issues/32#issuecomment-4182117621)
in #32, only DGX OS can boot from the factory firmware. If NixOS can't boot
from the factory firmware, you need to update firmware from DGX OS first.

The module enables [fwupd](https://fwupd.org/) for firmware updates. NVIDIA
publishes DGX Spark firmware to the Linux Vendor Firmware Service (LVFS). To
check for available updates:

```bash
fwupdmgr get-updates
```

To install available updates:

```bash
fwupdmgr update
```

## Playbooks

This repository includes devshells for NVIDIA DGX Spark playbooks from https://build.nvidia.com/spark:

| Playbook                                                                | Description                                                     |        Type         | Tested on NixOS | Tested on DGX OS |
| ----------------------------------------------------------------------- | --------------------------------------------------------------- | :-----------------: | :-------------: | :--------------: |
| [ComfyUI](./playbooks/comfyui/README.md)                                | Run ComfyUI with Stable Diffusion 1.5 for AI image generation   |    🟢 Full Nix²     |       ✅        |        ✅        |
| [Connect Two Sparks](./playbooks/connect-two-sparks/README.md)          | Connect two DGX Spark systems via QSFP                          |    🟢 Full Nix²     |       ✅        |       ☑️¹        |
| [DGX Dashboard](./playbooks/dgx-dashboard/README.md)                    | Set up DGX Dashboard for system monitoring                      |    🟢 Full Nix²     |       ✅        |       ☑️¹        |
| [FLUX.1 Dreambooth](./playbooks/flux-dreambooth/README.md)              | FLUX.1 Dreambooth LoRA fine-tuning                              |    🟠 Container³    |       ✅        |        ✅        |
| [Multi-Agent Chatbot](./playbooks/multi-agent-chatbot/README.md)        | Build and deploy a multi-agent chatbot                          |    🟠 Container³    |       ✅        |        ✅        |
| [Multi-modal Inference](./playbooks/multimodal-inference/README.md)     | Run multi-modal inference with vision-language models           |    🟠 Container³    |       ✅        |        ✅        |
| [NCCL for Two Sparks](./playbooks/nccl-two-sparks/README.md)            | Multi-node GPU communication with NCCL                          |    🟢 Full Nix²     |       ✅        |       ☑️¹        |
| [NVFP4](./playbooks/nvfp4/README.md)                                    | FP4 model quantisation with TensorRT Model Optimizer            |    🟠 Container³    |       ✅        |                  |
| [OpenShell](./playbooks/openshell/README.md)                            | Secure long-running AI agents with OpenShell sandbox            | 🔵 Nix + Container⁴ |       ✅        |                  |
| [PyTorch Fine-tuning Container](./playbooks/pytorch-finetune/README.md) | Fine-tune models with PyTorch on DGX Spark                      |    🟠 Container³    |       ✅        |                  |
| [PyTorch Fine-tuning Nix](./playbooks/pytorch-finetune-nix/README.md)   | Fine-tune models with PyTorch (Nix native, no containers)       |    🟢 Full Nix²     |       ✅        |        ✅        |
| [Speculative Decoding](./playbooks/speculative-decoding/README.md)      | Speculative decoding for faster inference                       |    🟠 Container³    |       ✅        |                  |
| [TRT-LLM](./playbooks/trt-llm/README.md)                                | TensorRT-LLM for optimised inference                            |    🟠 Container³    |       ✅        |        ✅        |
| [vLLM Container](./playbooks/vllm-container/README.md)                  | Run vLLM inference server with Qwen2.5-Math-1.5B-Instruct model |    🟠 Container³    |       ✅        |        ✅        |
| [vLLM Nix](./playbooks/vllm-nix/README.md)                              | Run vLLM inference server natively (Nix native, no containers)  |    🟢 Full Nix²     |       ✅        |        ✅        |

¹ Pre-installed on DGX OS
² **Full Nix**: Fully reproducible — all dependencies installed via Nix
³ **Container**: Nix provides podman, but containers are pulled/built at runtime
⁴ **Nix + Container**: CLI tools packaged via Nix, but containers are managed by the tool at runtime

## Caching

Unfortunately CUDA packages are not currently cached by the NixOS default
caches. There are community caches, but they currently don't provide
aarch64-linux packages. See https://nixos.wiki/wiki/CUDA for general caching
details.

To avoid rebuilding large CUDA packages, use the graham33 Cachix cache:

```bash
cachix use graham33
```

Install cachix first if needed: https://docs.cachix.org/installation

## nixos-anywhere (Experimental)

> [!WARNING]
> This has not been tested yet. Use at your own risk.

You can install NixOS on a DGX Spark remotely using
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere). This is
useful for headless setups where you have SSH access to the target machine.

```bash
nix run github:nix-community/nixos-anywhere -- --flake github:graham33/nixos-dgx-spark#dgx-spark root@<ip>
```

This partitions the NVMe disk and installs NixOS with the DGX Spark module
enabled. You may want to customise `nixos-anywhere/configuration.nix` (e.g. to
add SSH keys or change the hostname) — clone the repo and point `--flake` at
your local checkout instead.

To test the disk configuration in a VM without installing:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#dgx-spark --vm-test
```

See the [nixos-anywhere documentation](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
for full details and requirements.

## License

MIT License - see [LICENSE](LICENSE) for details.
