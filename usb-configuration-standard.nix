{ config, pkgs, lib, ... }:

{
  imports = [
    ./usb-configuration-base.nix
    ./modules/dgx-spark.nix
  ];

  # Enable DGX Spark support but use standard NixOS kernel
  hardware.dgx-spark = {
    enable = true;
    useNvidiaKernel = false;
  };
}
