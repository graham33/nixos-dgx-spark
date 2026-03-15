{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.dgx-dashboard;
  pkg = pkgs.callPackage ../packages/dgx-dashboard { };
in
{
  options.services.dgx-dashboard = {
    enable = lib.mkEnableOption "DGX Dashboard";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11000;
      description = "Port for the dashboard web server.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.dgx-dashboard-service-user = {
      isSystemUser = true;
      group = "dgx-dashboard-service-group";
      description = "DGX Dashboard service user";
    };

    users.groups.dgx-dashboard-service-group = { };

    systemd.services.dgx-dashboard = {
      description = "NVIDIA DGX Dashboard Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "dgx-dashboard-admin.service" ];

      path = [ config.hardware.nvidia.package.bin ];

      serviceConfig = {
        User = "dgx-dashboard-service-user";
        Group = "dgx-dashboard-service-group";
        ExecStart = "${pkg}/bin/dashboard-service -port ${toString cfg.port} serve";
        Restart = "always";
        StartLimitIntervalSec = 30;
        StartLimitBurst = 3;
        StandardOutput = "append:/var/log/dgx-dashboard-service.log";
        StandardError = "append:/var/log/dgx-dashboard-service.err.log";
      };
    };

    systemd.tmpfiles.rules = [
      "d /opt/nvidia/dgx-dashboard-service 0755 root root -"
    ];

    systemd.services.dgx-dashboard-admin = {
      description = "NVIDIA DGX Dashboard Admin Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "dbus.service" "systemd-tmpfiles-setup.service" ];

      serviceConfig = {
        ExecStart = "${pkg}/bin/dashboard-admin";
        Restart = "always";
      };
    };

    services.dbus.packages = [
      (pkgs.writeTextDir "share/dbus-1/system.d/com.nvidia.dgx.dashboard.admin1.conf" ''
        <!DOCTYPE busconfig PUBLIC
         "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
         "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
            <policy user="root">
                <allow own="com.nvidia.dgx.dashboard.admin1"/>
            </policy>
            <policy group="dgx-dashboard-service-group">
                <deny own="com.nvidia.dgx.dashboard.admin1"/>
                <allow send_destination="com.nvidia.dgx.dashboard.admin1"/>
                <allow send_interface="com.nvidia.dgx.dashboard.admin1"/>
            </policy>
            <policy context="default">
                <deny own="com.nvidia.dgx.dashboard.admin1"/>
                <deny send_destination="com.nvidia.dgx.dashboard.admin1"/>
                <deny send_interface="com.nvidia.dgx.dashboard.admin1"/>
            </policy>
        </busconfig>
      '')
    ];

    services.logrotate.settings = {
      dgx-dashboard-admin = {
        files = "/var/log/dgx-dashboard-admin*.log";
        su = "root root";
        create = "0644 root root";
        rotate = 6;
        frequency = "daily";
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
      };
      dgx-dashboard-service = {
        files = "/var/log/dgx-dashboard-service*.log";
        create = "0644 dgx-dashboard-service-user dgx-dashboard-service-group";
        rotate = 6;
        frequency = "daily";
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
      };
    };
  };
}
