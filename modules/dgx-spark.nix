{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.hardware.dgx-spark;

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;
  baseKernel = pkgs.linux_6_17;

  dgxKernelConfig = import
    (
      ../kernel-configs + "/nvidia-dgx-spark-${kernelSource.nvidiaKernelVersion}.nix"
    )
    { inherit lib; };

  nvidiaKernelPatches = [
    {
      name = "rust-gendwarfksyms-fix";
      patch = ../patches/rust-gendwarfksyms-fix.patch;
    }
  ];

  nvidiaKernel = pkgs.linuxPackagesFor (
    baseKernel.override {
      argsOverride = {
        src = kernelSource.mkNvidiaKernelSource pkgs;
        version = "${kernelSource.nvidiaKernelVersion}-nvidia";
        modDirVersion = kernelSource.nvidiaKernelVersion;
        kernelPatches = nvidiaKernelPatches;
      };

      enableCommonConfig = true;
      ignoreConfigErrors = true;

      structuredExtraConfig =
        dgxKernelConfig
        // (with lib.kernel; {
          SECURITY_APPARMOR_BOOTPARAM_VALUE = freeform "1";
          SECURITY_APPARMOR_RESTRICT_USERNS = lib.mkForce yes;

          USB_STORAGE = yes;
          USB_UAS = yes;
          OVERLAY_FS = yes;

          UEVENT_HELPER = no;

          UBUNTU_HOST = no;
        });
    }
  );
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
    nixpkgs.overlays = [ (import ../overlays/linux-6.17.nix) ];

    boot.kernelPackages = if cfg.useNvidiaKernel then nvidiaKernel else pkgs.linuxPackages_6_17;

    boot.kernelParams = [
      "console=tty1"
    ];

    boot.blacklistedKernelModules = [
      "nouveau"
      "r8169"
      "coresight_etm4x"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaPersistenced = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };

    hardware.enableRedistributableFirmware = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    hardware.nvidia-container-toolkit.enable = true;
  };
}
