{ config, lib, pkgs, ... }:

let
  baseKernel = pkgs.linux_6_17;
  nvidiaKernelVersion = "6.17.1";
  nvidiaKernel = pkgs.linuxPackagesFor (baseKernel.override {
    argsOverride = rec {
      # Use the NVIDIA kernel source
      src = pkgs.fetchFromGitHub {
        owner = "NVIDIA";
        repo = "NV-Kernels";
        rev = "24.04_linux-nvidia-6.17-next";
        hash = "sha256-lPp7RFvZcPhV5v6FOxCVIB53vpNujvvP0NAW6iRaiF8=";
      };

      version = "${nvidiaKernelVersion}-nvidia";
      modDirVersion = nvidiaKernelVersion;
      # Use NVIDIA-patched defconfig from the source rather than the NixOS one
      defconfig = "defconfig";

      structuredExtraConfig = with lib.kernel; {
        # Change some settings from the upstream NVIDIA defconfig
        FAULT_INJECTION = lib.mkForce no; # fault injection
        SECURITY_APPARMOR_RESTRICT_USERNS = yes; # NixOS enables AppArmor by default
        UBUNTU_HOST = no; # Not Ubuntu!
      };
    };
  });
in {
  # Use the latest Linux kernel
  boot.kernelPackages = nvidiaKernel;

  boot.kernelParams = [
    "console=tty1"          # VGA console
  ];
  
  boot.blacklistedKernelModules = [
    "nouveau" # Ensure we use the NVIDIA open driver
    "r8169" # Use the r8127 driver in the NVIDIA kernel
  ];
  
  # Enable NVIDIA open driver
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;  # Use the open-source NVIDIA driver
    nvidiaPersistenced = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  hardware.enableRedistributableFirmware = true;
  
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;
}
