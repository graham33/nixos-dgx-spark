{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.dgx-spark;

  connectx7Hotplug = pkgs.callPackage ../packages/dgx-spark-mlnx-hotplug { };
in
{
  options.hardware.dgx-spark.connectx7Hotplug = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Enable ConnectX-7 PCIe hot-plug support using NVIDIA's udev helper
      and the mtk-pcie-hotplug kernel module. Only takes effect with the
      NVIDIA kernel, which is the only one that provides that module.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.useNvidiaKernel && cfg.connectx7Hotplug) {
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
