{ config, lib, pkgs, ... }:

{
  # Use the latest Linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ARM64-specific optimizations with NVIDIA support
  boot.kernelParams = [
    "console=tty1"          # VGA console
  ];
  
  # Blacklist only nouveau, allow NVIDIA open driver
  boot.blacklistedKernelModules = [ "nouveau" ];
  
  # Enable NVIDIA open driver
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;  # Use the open-source NVIDIA driver
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Additional hardware support
  hardware.enableRedistributableFirmware = true;
  
  # Allow unfree firmware if needed
  nixpkgs.config.allowUnfree = true;
}
