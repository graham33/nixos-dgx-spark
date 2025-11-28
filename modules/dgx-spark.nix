{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.dgx-spark;
  baseKernel = pkgs.linux_6_17;
  nvidiaKernelVersion = "6.17.1";

  # Import generated NVIDIA DGX configuration
  dgxKernelConfig = import ../kernel-configs/nvidia-dgx-spark-6.17.1.nix { inherit lib; };

  nvidiaKernel = pkgs.linuxPackagesFor (baseKernel.override {
    argsOverride = rec {
      # Use the NVIDIA kernel source
      src = pkgs.fetchFromGitHub {
        owner = "NVIDIA";
        repo = "NV-Kernels";
        # From https://github.com/NVIDIA/NV-Kernels/commits/24.04_linux-nvidia-6.17-next/
        rev = "47ca203bcc5f4e1580c06fe1074d71497462ac8b";
        hash = "sha256-lPp7RFvZcPhV5v6FOxCVIB53vpNujvvP0NAW6iRaiF8=";
      };

      # Apply Rust gendwarfksyms fix patch
      kernelPatches = [
        {
          name = "rust-gendwarfksyms-fix";
          patch = ../patches/rust-gendwarfksyms-fix.patch;
        }
      ];

      version = "${nvidiaKernelVersion}-nvidia";
      modDirVersion = nvidiaKernelVersion;
      enableCommonConfig = true; # Enable NixOS defaults for dependency resolution
      ignoreConfigErrors = true; # Ignore unused config options

      # Use comprehensive NVIDIA DGX configuration with NixOS-specific overrides
      structuredExtraConfig = (lib.filterAttrs
        (name: value:
          # Remove options that conflict with NixOS requirements or don't exist in this kernel
          !lib.elem name [
            "BLK_DEV_DM" # Device mapper - let NixOS handle this
            "BLK_DEV_DM_BUILTIN" # Device mapper builtin - let NixOS handle this
            "PAHOLE_VERSION" # Tool version - let NixOS handle this
            "RUSTC_LLVM_VERSION" # Compiler version - let NixOS handle this
            "RUSTC_VERSION" # Compiler version - let NixOS handle this
            "GCC_VERSION" # Compiler version - let NixOS handle this
            "LD_VERSION" # Linker version - let NixOS handle this
            "VERSION_SIGNATURE" # Version signature - let NixOS handle this
            "LOCALVERSION" # Local version - let NixOS handle this
            "LOCALVERSION_AUTO" # Local version auto - let NixOS handle this
            "INITRAMFS_SOURCE" # Initramfs source - let NixOS handle this
            "SYSTEM_TRUSTED_KEYS" # System trusted keys - debian-specific paths
            "SYSTEM_REVOCATION_KEYS" # System revocation keys - debian-specific paths
            "MODULE_SIG_KEY" # Module signing key - let NixOS handle this
            "SYSTEM_BLACKLIST_HASH_LIST" # System blacklist hash list - empty string causes build failure
            "EXTRA_FIRMWARE" # Extra firmware - empty string causes build failure
            "IPE_BOOT_POLICY" # IPE boot policy - empty string causes build failure
            "USB_STORAGE" # USB storage - ensure built-in for USB boot
            "USB_UAS" # USB Attached SCSI - ensure built-in for modern USB devices
            "OVERLAY_FS" # Overlay filesystem - ensure built-in for live boot
            "UEVENT_HELPER" # Legacy uevent helper - let NixOS use modern udev
          ]
        )
        dgxKernelConfig) // (with lib.kernel; {
        # Critical NixOS security options that may need to override DGX defaults
        SECURITY_APPARMOR_BOOTPARAM_VALUE = freeform "1";
        SECURITY_APPARMOR_RESTRICT_USERNS = lib.mkForce yes; # NixOS enables AppArmor by default

        # USB storage support for USB boot
        USB_STORAGE = yes; # Build into kernel for USB boot
        USB_UAS = yes; # USB Attached SCSI for modern USB devices
        OVERLAY_FS = yes; # Overlay filesystem for live boot

        # Device management - use modern udev instead of legacy helper
        UEVENT_HELPER = no; # Disable legacy uevent helper for proper udev operation

        # Platform-specific overrides
        UBUNTU_HOST = no; # Not Ubuntu!
      });
    };
  });
in
{
  options.hardware.dgx-spark = {
    enable = mkEnableOption "DGX Spark hardware support";

    useNvidiaKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the NVIDIA kernel instead of the standard NixOS kernel";
    };
  };

  config = mkIf cfg.enable {
    # Use the NVIDIA kernel if enabled, otherwise use explicit 6.17 kernel
    boot.kernelPackages =
      if cfg.useNvidiaKernel
      then nvidiaKernel
      else pkgs.linuxPackages_6_17;

    boot.kernelParams = [
      "console=tty1" # VGA console
    ];

    boot.blacklistedKernelModules = [
      "nouveau" # Ensure we use the NVIDIA open driver
      "r8169" # Use the r8127 driver in the NVIDIA kernel
      "coresight_etm4x" # ARM CoreSight debugging (can cause overhead on DGX)
    ];

    # Enable NVIDIA open driver
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      open = true; # Use the open-source NVIDIA driver
      nvidiaPersistenced = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };

    hardware.enableRedistributableFirmware = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;

    # TODO: firefox doesn't build with CUDA 13 yet (issues with cudnn-frontend and
    # onnxruntime)
    # nixpkgs.overlays = [ (import ../overlays/cuda-13.nix) ];

    # Set up podman for NVIDIA containers
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    hardware.nvidia-container-toolkit.enable = true;
  };
}
