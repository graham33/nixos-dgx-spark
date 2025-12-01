{ config, pkgs, lib, ... }:

{
  imports = [
    ./usb-configuration-base.nix
    ./modules/dgx-spark.nix
  ];

  # Enable DGX Spark support with NVIDIA kernel (default)
  hardware.dgx-spark.enable = true;

  # Specialisation for standard NixOS kernel
  # Select "Standard Kernel" from the boot menu to use this
  specialisation.standard-kernel = {
    inheritParentConfig = true;
    configuration = {
      hardware.dgx-spark.useNvidiaKernel = lib.mkForce false;

      # Update boot menu entry to indicate standard kernel
      system.nixos.tags = [ "standard-kernel" ];
    };
  };
}
