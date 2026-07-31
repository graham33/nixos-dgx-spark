# NixOS VM test for the dgx-dashboard module. Built with a plain nixpkgs
# (no CUDA, no overlays) so the whole VM closure substitutes from
# cache.nixos.org.
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "dgx-dashboard";

  nodes.machine = { lib, pkgs, ... }: {
    imports = [ ../modules/dgx-dashboard.nix ];

    services.dgx-dashboard.enable = true;

    # The module puts the NVIDIA driver's userspace tools on the service
    # path; stub them out so the unfree driver never enters the test
    # closure and the test runs on machines without the real hardware.
    systemd.services.dgx-dashboard.path = lib.mkForce [
      (pkgs.writeShellScriptBin "nvidia-smi" "echo stub")
    ];

    environment.systemPackages = [ pkgs.curl ];

    virtualisation.memorySize = 1024;
  };

  testScript = ''
    machine.wait_for_unit("dgx-dashboard-admin.service")
    machine.wait_for_unit("dgx-dashboard.service")
    machine.wait_for_open_port(11000)
    machine.succeed("curl -fsS http://localhost:11000/ >/dev/null")
  '';
}
