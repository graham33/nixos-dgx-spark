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
    ./dgx-spark-connectx7.nix
    ./vllm.nix
  ];

  options.hardware.dgx-spark = {
    enable = mkEnableOption "DGX Spark hardware support";

    useNvidiaKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the NVIDIA kernel instead of the standard NixOS kernel";
    };

    cppcAutonomousMode = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable CPPC autonomous selection mode (`cppc_cpufreq.auto_sel_mode=1`).

        On the GB10, without autonomous CPPC the memory fabric never enters
        autonomous performance management, which cripples single-thread memory
        bandwidth (~3x lower) and llama.cpp prompt-processing (~4% lower) vs
        stock DGX OS. Stock DGX OS boots with autonomous mode enabled; the
        NVIDIA `-next` kernel ships the driver support but defaults it off, so
        it must be enabled explicitly.

        Requires the NVIDIA kernel (`useNvidiaKernel = true`), whose cppc_cpufreq
        driver carries the autonomous-mode series.
      '';
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
      # Module-autoload kill switches for kernel vulnerabilities with no
      # upstream patch at the time of writing:
      #
      #   algif_aead  — CVE-2026-31431 "Copy Fail" (AF_ALG AEAD local privesc)
      #   esp4, esp6  — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
      #   rxrpc       — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
      #
      # Each of these modules is requested by name from a kernel subsystem
      # (AF_ALG, xfrm_user, AF_RXRPC respectively), bypassing modprobe alias
      # blacklists. `module_blacklist=` is a kernel-level kill switch:
      # request_module() refuses to invoke modprobe at all, so this is
      # robust against both autoload (e.g. socket(AF_ALG)+bind("aead")) and
      # explicit `modprobe`. NB: `boot.blacklistedKernelModules` alone is
      # NOT sufficient — modprobe's `blacklist` directive only blocks
      # alias-based autoloads, and these kernel paths request the module
      # by name (after dash/underscore normalisation), bypassing it.
      # Requires a reboot to apply.
      "module_blacklist=algif_aead,esp4,esp6,rxrpc"
    ] ++ lib.optional (cfg.useNvidiaKernel && cfg.cppcAutonomousMode) "cppc_cpufreq.auto_sel_mode=1";

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
    # Compile CUDA code only for the Spark's GB10 Blackwell GPU. Without this,
    # packages like ucc build for all nine architectures nixpkgs supports
    # (sm_75 through sm_121), which can exhaust memory and OOM a rebuild.
    #
    # NB: this does not match the Flox cache, which is built with nixpkgs'
    # default (full) capability list, so CUDA-dependent packages are rebuilt
    # from source. Set `nixpkgs.config.cudaCapabilities = [ ]` to restore the
    # default and get the cache hits back -- see "Matching the Flox cache with
    # cudaCapabilities" in the README for the trade-off.
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

    # RDMA over the ConnectX ports needs to pin the memory it registers, and
    # the NixOS default memlock ceiling of 8 MB is far too low: ibv_reg_mr
    # fails and UCX floods the log with "Cannot allocate memory ... Please set
    # max locked memory (ulimit -l) to 'unlimited'", which then looks like a
    # network fault further up. Stock DGX OS sets a limit of roughly the whole
    # of RAM, so without this a Spark pair is asymmetric and multi-node runs
    # fail on the NixOS side only. Note the *hard* limit matters -- an
    # unprivileged `ulimit -l` cannot raise it.
    security.pam.loginLimits = [
      { domain = "*"; type = "soft"; item = "memlock"; value = "unlimited"; }
      { domain = "*"; type = "hard"; item = "memlock"; value = "unlimited"; }
    ];

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
