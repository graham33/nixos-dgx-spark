# Hardware configuration for DGX Spark
# This file contains the hardware-specific configuration for DGX Spark systems.
# You should run 'nixos-generate-config' to generate a system-specific version,
# but this template provides the DGX Spark-specific baseline.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # DGX Spark typical kernel modules
  boot.initrd.availableKernelModules = [
    "nvme" # NVMe storage
    "usb_storage" # USB storage support
    "usbhid" # USB input devices
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # File system configuration - PLEASE UPDATE THESE UUIDs!
  # Run 'blkid' to get the correct UUIDs for your system
  fileSystems."/" = {
    # REPLACE WITH YOUR ROOT FILESYSTEM UUID
    device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    # REPLACE WITH YOUR BOOT FILESYSTEM UUID
    device = "/dev/disk/by-uuid/XXXX-XXXX";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Swap configuration - REPLACE WITH YOUR SWAP UUID
  swapDevices = [
    { device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"; }
  ];

  # Platform configuration for DGX Spark (ARM64)
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
