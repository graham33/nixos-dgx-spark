{ config, pkgs, lib, ... }:

{
  imports = [
    ./usb-configuration-base.nix
    ./modules/dgx-spark.nix
  ];

  # Enable DGX Spark support with NVIDIA kernel
  hardware.dgx-spark.enable = true;
}
