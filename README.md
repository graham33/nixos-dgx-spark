# NixOS DGX Spark

NixOS configuration for NVIDIA DGX Spark systems. Provides a simple USB image
and a NixOS module to add some settings required for DGX Spark systems.

## Building and writing the USB boot image

```bash
nix build .#usb-image
sudo dd if=$(echo result/iso/*.iso) of=/dev/your_usb_disk_device bs=1M status=progress
```

Then disable Secure Boot in the DGX Spark BIOS and boot from the USB drive.

You can then following the installation instructions in the NixOS manual: https://nixos.org/manual/nixos/stable/#sec-installation-manual

### Using the DGX Spark module

This module includes a custom kernel build optimized for NVIDIA DGX Spark
systems. The kernel configuration is generated from NVIDIA's Debian annotations
using `scripts/generate-dgx-config.py` and compared with NixOS defaults using
`scripts/compare-configs.py` to ensure compatibility.

Other projects can import this flake and use the DGX Spark module:

```nix
{
  inputs.dgx-spark.url = "github:graham33/nixos-dgx-spark";

  outputs = { nixpkgs, dgx-spark, ... }: {
    nixosConfigurations.mySystem = nixpkgs.lib.nixosSystem {
      modules = [
        dgx-spark.nixosModules.dgx-spark
        # your other modules
      ];
    };
  };
}
```

## NixOS Usage

See https://nixos.wiki/wiki/CUDA for caching details.

## License

MIT License - see [LICENSE](LICENSE) for details.
