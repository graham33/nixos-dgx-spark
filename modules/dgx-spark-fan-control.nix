{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.dgx-spark;
  fanCfg = cfg.fanControl;

  fanControl = pkgs.callPackage ../packages/dgx-spark-fan-control { };
  fanControlKmod = config.boot.kernelPackages.callPackage ../packages/dgx-spark-fan-control/kmod.nix { };
in
{
  options.hardware.dgx-spark.fanControl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install [dgx-spark-fan-control](https://github.com/christopherowen/dgx-spark-fan-control)'s
        fan-floor driver and its `dgx-fan-control` command.

        The driver lets Linux raise the minimum RPM of the Spark's fans
        through the embedded controller, which keeps applying NVIDIA's own
        fan curve on top: it can add cooling but never take any away. It
        loads at boot in state 0, which leaves the fans to NVIDIA's curve;
        `dgx-fan-control set-state 1`..`12` raises the floor by hand (2,700
        to 13,500 RPM) until `dgx-fan-control automatic`.

        This is an experimental, out-of-tree module, validated upstream on
        DGX OS's 6.17 kernel with EC firmware 3.5.8, and the firmware has a
        known race that can wedge its mailbox: see upstream's
        troubleshooting guide.
      '';
    };

    curve.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run upstream's temperature curve as the `dgx-fan-control` service.
        Every 2 seconds it sets the fan floor from the hottest thermal zone,
        from none below 50 °C to both fans at full speed from 70 °C, and
        stopping it hands the fans back to NVIDIA's curve.

        It expects to be the only writer: while it runs, a manual
        `set-state` is overridden within seconds, so stop it first
        (`systemctl stop dgx-fan-control`). Requires `fanControl.enable`.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = fanCfg.curve.enable -> fanCfg.enable;
          message = "hardware.dgx-spark.fanControl.curve.enable requires hardware.dgx-spark.fanControl.enable.";
        }
      ];
    }

    (lib.mkIf (cfg.enable && fanCfg.enable) {
      assertions = [
        {
          assertion = cfg.useNvidiaKernel;
          message = "hardware.dgx-spark.fanControl requires hardware.dgx-spark.useNvidiaKernel; the driver is only validated on NVIDIA's kernel.";
        }
      ];

      # The driver declares no FF-A device table, so nothing autoloads it.
      boot.extraModulePackages = [ fanControlKmod ];
      boot.kernelModules = [ "dgx_ec_fan_control" ];

      environment.systemPackages = [ fanControl ];

      # Upstream's systemd/dgx-fan-control.service. Exit 69 means the driver
      # is missing or its firmware transport failed; the daemon has already
      # tried to restore automatic control, and upstream wants an operator to
      # look before it runs again, so it is not restarted.
      systemd.services.dgx-fan-control = lib.mkIf fanCfg.curve.enable {
        description = "DGX Spark additive fan-floor controller";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        wants = [ "systemd-modules-load.service" ];
        startLimitIntervalSec = 300;
        startLimitBurst = 3;
        serviceConfig = {
          Type = "simple";
          ExecStart = "${lib.getExe fanControl} daemon";
          Restart = "on-failure";
          RestartPreventExitStatus = 69;
          RestartSec = "30s";
          TimeoutStopSec = "30s";
          CapabilityBoundingSet = "";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateNetwork = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelLogs = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = "AF_UNIX";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };
    })
  ];
}
