{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.dgx-spark;
  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;

  connectx7HotplugModule = config.boot.kernelPackages.callPackage ../packages/dgx-spark-cx7-hotplug-module {
    src = kernelSource.mkNvidiaKernelSource pkgs;
  };

  connectx7Hotplug = pkgs.callPackage ../packages/dgx-spark-mlnx-hotplug { };
in
{
  options.hardware.dgx-spark.connectx7Hotplug = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Enable ConnectX-7 PCIe hot-plug support using NVIDIA's udev helper
      and the out-of-tree mtk-pcie-hotplug kernel module.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.connectx7Hotplug) {
    boot.extraModulePackages = [ connectx7HotplugModule ];
    boot.kernelModules = [ "mtk-pcie-hotplug" ];

    services.udev.packages = [ connectx7Hotplug ];

    # NVIDIA's Debian package creates this marker in its post-install script.
    # The helper deliberately leaves hot-plug disabled when the marker is absent.
    environment.etc."nvidia/cx7-hotplug-enabled" = {
      text = ''
        # CX7 Hotplug Configuration
        # Presence of this file enables ConnectX-7 hot-plug power management.
      '';
    };
  };
}
