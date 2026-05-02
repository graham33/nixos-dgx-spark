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

  rawNvidiaKernel = pkgs.linuxPackagesFor (
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

  # Strip embedded references to the kernel `-dev` output from .ko files. The
  # nvidia kernel-modules build (nixpkgs PR #498612) declares
  # `allowedReferences = [ ]` on the module derivation, but the .ko files end
  # up with __FILE__-derived header paths in `.rodata.str1.8` that point into
  # the kernel-dev store path, so the closure check fails. Run
  # remove-references-to as a postFixup to scrub them. Stock x86_64 kernels
  # don't trigger this — the leak is specific to non-stock (e.g. patched
  # aarch64) kernels where the build environment leaves these strings around.
  scrubKernelDevRefs = drv:
    drv.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        if [ -d "$out/lib/modules" ]; then
          find $out/lib/modules -name '*.ko' -print0 \
            | xargs -0 -r ${pkgs.removeReferencesTo}/bin/remove-references-to \
                -t ${rawNvidiaKernel.kernel.dev}
        fi
      '';
    });

  nvidiaKernel = rawNvidiaKernel;
in
{
  imports = [
    ./dgx-dashboard.nix
    ./vllm.nix
  ];

  options.hardware.dgx-spark = {
    enable = mkEnableOption "DGX Spark hardware support";

    useNvidiaKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the NVIDIA kernel instead of the standard NixOS kernel";
    };
  };

  config = mkIf cfg.enable {
    # Add the Flox binary cache as a substituter for pre-built CUDA packages.
    # Flox is authorized by NVIDIA to redistribute CUDA binaries, so packages
    # like cudatoolkit, nccl, cuDNN, torch, etc. can be fetched as pre-built
    # binaries instead of compiling from source.
    # https://flox.dev/blog/the-flox-catalog-now-contains-nvidia-cuda/
    nix.settings = {
      extra-substituters = [ "https://cache.flox.dev" ];
      extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    };

    nixpkgs.overlays = [ (import ../overlays/linux-6.17.nix) ];

    boot.kernelPackages = if cfg.useNvidiaKernel then nvidiaKernel else pkgs.linuxPackages_6_17;

    boot.kernelParams = [
      "console=tty1"
      # CVE-2026-31431 "Copy Fail" — local privilege escalation via the
      # AF_ALG AEAD socket interface. No upstream kernel patch shipped at
      # the time of writing. `module_blacklist=` is a kernel-level kill
      # switch: request_module() refuses to invoke modprobe at all, so
      # this is robust against both autoload (socket(AF_ALG)+bind("aead"))
      # and explicit `modprobe algif_aead`. NB: `boot.blacklistedKernelModules`
      # alone is NOT sufficient — modprobe's `blacklist` directive only
      # blocks alias-based autoloads, and the kernel's AF_ALG path requests
      # the module by name (after dash/underscore normalization), bypassing
      # it. Requires a reboot to apply.
      "module_blacklist=algif_aead"
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
      # Apply scrubKernelDevRefs to the .open / .mod kernel module variants —
      # bypass boot.kernelPackages.apply (which chains another `.extend` and
      # re-evaluates `nvidiaPackages` through the makeExtensible fixed point,
      # discarding any overrides we'd put on the kernel package set itself).
      package =
        let
          prod = config.boot.kernelPackages.nvidiaPackages.production;
        in
        prod
        // {
          open = scrubKernelDevRefs prod.open;
          mod = scrubKernelDevRefs prod.mod;
        };
    };

    hardware.enableRedistributableFirmware = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;
    nixpkgs.config.cudaCapabilities = [ "12.0" "12.1" ];

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # Trust the podman bridge so containers can reach host services
    networking.firewall.trustedInterfaces = [ "podman+" ];

    hardware.nvidia-container-toolkit.enable = true;

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
      iperf3
      ethtool
      rdma-core
    ];

    services.dgx-dashboard.enable = true;
    services.fwupd.enable = true;
  };
}
