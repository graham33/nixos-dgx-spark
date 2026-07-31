# Boots the system a user would get from the dgx-spark template
# (its configuration.nix plus the dgx-spark module) in a QEMU VM, on the
# custom NVIDIA kernel. QEMU's generic virt machine direct-boots the
# kernel, and the DGX kernel config keeps the virtio/9p drivers, so no
# real hardware is needed. The GPU itself is absent: GPU-dependent
# services are allowed to fail, and the test asserts the system reaches
# multi-user.target on the NVIDIA kernel with core services up.
#
# The closure includes the custom kernel, so this check is expensive and
# runs in CI's full-build lane only (never the per-PR build job).
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "dgx-spark-boot";

  # The dgx-spark module sets nixpkgs.overlays and nixpkgs.config (the
  # 6.17 kernel overlay, allowUnfree for the NVIDIA driver), so the node
  # must evaluate its own pkgs rather than reusing the test's.
  node.pkgsReadOnly = false;

  nodes.machine = { lib, ... }: {
    imports = [
      ../templates/dgx-spark/configuration.nix
      ../modules/dgx-spark.nix
    ];

    # The template enables a full GNOME desktop; disable it here to keep
    # the test closure within reason.
    services.xserver.enable = lib.mkForce false;
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    # The qemu-vm test module force-overrides services.xserver.videoDrivers,
    # removing "nvidia" and tripping the container-toolkit assertion; there
    # is no GPU in the VM anyway.
    hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;

    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # The custom NVIDIA kernel is what booted
    machine.succeed("uname -r | grep -q '^6\\.17\\.13'")

    # Core services from the template and module
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("podman.socket")
    machine.succeed("test -S /run/docker.sock")
    machine.succeed("podman info >/dev/null")
  '';
}
